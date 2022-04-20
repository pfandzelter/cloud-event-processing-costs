const functions = require('@google-cloud/functions-framework');
const { Firestore } = require("@google-cloud/firestore");

const selectCollection = process.env.SELECT_COLLECTION;
const projectId = process.env.PROJECT_ID;
const windowSize = Number(process.env.WINDOW_SIZE);
const interval = Number(process.env.INTERVAL);

const firestore = new Firestore({
    projectId: projectId,
});

let logFirestore = (t, count) => {
    console.log(`FIRESTORE OP ${t}: ${count}`);
};

// test locally with
// npx @google-cloud/functions-framework --target=aggregate

functions.http('aggregate', async (req, res) => {
    try {
        let reading = req.body;

        const id = reading.identifier;
        const i = reading.valueInW;

        let now = (new Date()).getTime() / 1000;

        for (let t = 0; t < windowSize; t += interval) {
            let wid = id + "_" + t;
            let T = now - (now % windowSize) + t;

            let d = await firestore.collection(selectCollection).doc(wid).get();
            logFirestore("READ", 1);

            if (!d.exists) {
                d = await firestore.collection(selectCollection).doc(wid).set({
                    T: T,
                    Count: 1,
                    Min: i,
                    Max: i,
                    Mean: i,
                    SD: 0.0,
                    SD_M2: 0.0,
                });
                logFirestore("WRITE", 1);
                continue;
            }

            if (d.data().T == undefined || d.data().T == 0) {
                console.log("Failed to get window: no T")
                res.status(500).send("OK");
                return;
            }

            if (d.data().T < now-windowSize) {
                // emit
                console.log({
                    time: T+t*interval,
                    sensor: id,
                    count: d.data().Count,
                    min: d.data().Min,
                    max: d.data().Max,
                    mean: d.data().Mean,
                    sd: d.data().SD,
                })

                // reset window
                d = await firestore.collection(selectCollection).doc(wid).set({
                    T: T,
                    Count: 1,
                    Min: i,
                    Max: i,
                    Mean: i,
                    SD: 0.0,
                    SD_M2: 0.0,
                });

                logFirestore("WRITE", 1);
                continue;
            }

            // update window
            let oldCount = d.data().Count;
            let oldMin = d.data().Min;
            let oldMax = d.data().Max;
            let oldMean = d.data().Mean;
            let oldSD = d.data().SD;
            let oldSD_M2 = d.data().SD_M2;

            let newCount = oldCount + 1;
            let newMin = Math.min(oldMin, i);
            let newMax = Math.max(oldMax, i);
            let newMean = (oldMean*oldCount + i) / newCount;

            let delta = i - oldMean;
            let delta2 = i - (oldMean + delta/oldCount);
            let newSD_M2 = oldSD_M2 + delta*delta2;
            let newSD = Math.sqrt(newSD_M2 / newCount);

            d = await firestore.collection(selectCollection).doc(wid).set({
                T: d.data().T,
                Count: newCount,
                Min: newMin,
                Max: newMax,
                Mean: newMean,
                SD: newSD,
                SD_M2: newSD_M2,
            });
            logFirestore("WRITE", 1);
        }

        res.status(200).send("OK");
        return;
    } catch (e) {
        console.log(e);
        res.status(500).send(e);
        return;
    }
});