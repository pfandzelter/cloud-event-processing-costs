const functions = require('@google-cloud/functions-framework');
const { Firestore } = require("@google-cloud/firestore");
const collection = process.env.COLLECTION;
const projectId = process.env.PROJECT_ID;

const firestore = new Firestore({
    projectId: projectId,
});

let logFirestore = (t, count) => {
    console.log(`FIRESTORE OP ${t}: ${count}`);
};

functions.http('store', async (req, res) => {
    let reading = req.body;

    try {
        await firestore.collection(collection).add(reading);
        logFirestore("WRITE", 1);
    } catch (e) {
        console.log(e);
        res.status(500).send(e);
        return;
    }
    res.send("OK");
    return;
});
