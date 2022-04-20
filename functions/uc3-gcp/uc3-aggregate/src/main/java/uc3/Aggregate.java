package uc3;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.FirestoreOptions;
import com.google.cloud.functions.*;
import com.google.events.cloud.pubsub.v1.Message;
import com.google.gson.Gson;
import titan.ccp.model.records.ActivePowerRecord;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.util.stream.Collectors;

public class Aggregate implements HttpFunction, BackgroundFunction<Message> {
    private Firestore db;
    private final String collection;
    private final int windowSize;
    private final int interval;

    public Aggregate() {
        // get environment variable COLLECTION
        this.collection = System.getenv("SELECT_COLLECTION");
        // get environment variable PROJECT_ID
        String projectId = System.getenv("GOOGLE_CLOUD_PROJECT");
        // get environment variable WINDOW_SIZE
        this.windowSize = Integer.parseInt(System.getenv("WINDOW_SIZE"));
        // get environment variable INTERVAL
        this.interval = Integer.parseInt(System.getenv("INTERVAL"));

        // create Firestore instance
        try {
            FirestoreOptions firestoreOptions = FirestoreOptions.getDefaultInstance().toBuilder()
                    .setProjectId(projectId)
                    .setCredentials(GoogleCredentials.getApplicationDefault())
                    .build();
            this.db = firestoreOptions.getService();
        } catch (Error | IOException ignored) {

        }
    }

    private void logFirestore(String operation, int count) {
        System.out.printf("FIRESTORE OP %s: %d\n", operation, count);
    }

    @Override
    public void service(HttpRequest request, HttpResponse response)
            throws IOException {
        // step 1: parse JSON
        Gson gson = new Gson();
        Map map = gson.fromJson(request.getReader().lines().collect(Collectors.joining(System.lineSeparator())),
                Map.class);

        this.handle(map);
    }

    @Override
    public void accept(Message message, Context context) {
        if (message.getData() == null) {
            System.out.println("No message provided");
            return;
        }

        try {
            byte[] bytes = Base64.getDecoder().decode(message.getData().getBytes(StandardCharsets.UTF_8));
            ActivePowerRecord apr = ActivePowerRecord.fromByteBuffer(ByteBuffer.wrap(bytes));
            System.out.println("Received message: " + apr.toString());
            this.handle(new HashMap<String, Object>() {
                {
                    put("timestamp", apr.getTimestamp());
                    put("identifier", apr.getIdentifier());
                    put("valueInW", apr.getValueInW());
                }
            });
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void handle(Map map) throws IOException {

        // select the attrbute we want
        String id = (String) map.get("identifier");
        double i = (double) map.get("valueInW");

        // iterate over windows

        // check the firestore collection
        // get current time
        long now = System.currentTimeMillis() / 1000;

        // iterate over all the entries (= open windows)
        // add values to open windows
        // close windows when they are deadlined
        // create new windows if required
        // there should be 2*windowSize/interval - 1 windows open at all times
        // offsets -windowsize+interval, -windowsize+2interval, ..., 0, interval,
        // 2interval, ..., windowsize-interval
        //
        // - -|- - -
        // -|- - - -
        // |- - - - -|
        // | - - - -|-
        // | - - -|- -
        // | - -|- - -
        // | -|- - - -
        // | |- - - - -
        // 0 1|2 3 4 5 6 7 8 9 1 1
        //
        // Aggregation uc1 are based on
        // https://guava.dev/releases/22.0/api/docs/com/google/common/math/StatsAccumulator.html
        // * count
        // * min
        // * max
        // * mean
        // * populationStandardDeviation
        //

        for (long t = 0; t < windowSize; t += interval) {
            // get the timestamp
            String wid = String.format("%s_%d", id, t);

            long T = now - (now % windowSize) + t;

            // System.out.println("Getting document " + wid);
            DocumentReference d = db.collection(collection).document(wid);

            DocumentSnapshot doc = null;

            try {
                doc = d.get().get();
            } catch (Error | ExecutionException | InterruptedException ignored) {
            } finally {
                logFirestore("READ", 1);
            }

            if ((doc == null) || (!doc.exists())) {
                // create a new document

                try {
                    d.set(new HashMap<String, Object>() {
                        {
                            put("T", T);
                            put("Count", (int) 1);
                            put("Min", (double) i);
                            put("Max", (double) i);
                            put("Mean", (double) i);
                            put("SD", (double) 0.0);
                            put("SD_M2", (double) 0.0);
                        }
                    }).get();
                } catch (Error | ExecutionException | InterruptedException ignored) {
                }
                logFirestore("WRITE", 1);

                try {
                    doc = d.get().get();
                } catch (Error | ExecutionException | InterruptedException e) {
                    e.printStackTrace();
                    throw new IOException(e);
                } finally {
                    logFirestore("READ", 1);
                }
                continue;
            }

            if ((doc.get("T") == null) || ((long) doc.get("T") == 0)) {
                throw new IOException(String.format("Failed to get window: T does not exist: %s", doc.get("T")));
            }

            if ((long) doc.get("T") < now - windowSize) {
                // window is dead

                // emit
                System.out.printf(
                        "{\"time\":%s, \"sensor\": %s, \"count\": %s, \"min\": %s ,\"max\": %s, \"mean\": %s, \"sd\": %s }\n",
                        T + t * interval, id, doc.get("Count"), doc.get("Min"), doc.get("Max"), doc.get("Mean"),
                        doc.get("SD"));

                // reset window
                d.set(new HashMap<String, Object>() {
                    {
                        put("T", T);
                        put("Count", 1);
                        put("Min", i);
                        put("Max", i);
                        put("Mean", i);
                        put("SD", 0.0);
                        put("SD_M2", 0.0);
                    }
                });
                logFirestore("WRITE", 1);
                continue;
            }

            int oldCount = 0;
            if (doc.get("Count", Integer.class) != null) {
                oldCount = doc.get("Count", Integer.class);
            }

            double oldMin = 0;
            if (doc.get("Min", Double.class) != null) {
                oldMin = doc.get("Max", Double.class);
            }

            double oldMax = 0;
            if (doc.get("Max", Double.class) != null) {
                oldMax = doc.get("Max", Double.class);
            }

            double oldMean = 0;
            if (doc.get("Mean", Double.class) != null) {
                oldMean = doc.get("Mean", Double.class);
            }

            double oldSDM2 = 0;
            if (doc.get("SD_M2", Double.class) != null) {
                oldSDM2 = doc.get("SD_M2", Double.class);
            }

            int newCount = oldCount + 1;
            double newMin = Math.min(oldMin, i);
            double newMax = Math.max(oldMax, i);
            double newMean = oldMean * oldCount + i / newCount;

            // https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm
            // no idea if this is correctly implemented

            double delta = i - oldMean;
            double delta2 = i - (oldMean + delta / oldCount);
            double newSDM2 = oldSDM2 + delta * delta2;

            double newSD = (double) Math.sqrt(newSDM2 / newCount);

            d.set(new HashMap<String, Object>() {
                {
                    put("T", T);
                    put("Count", newCount);
                    put("Min", newMin);
                    put("Max", newMax);
                    put("Mean", newMean);
                    put("SD", newSD);
                    put("SD_M2", newSDM2);

                }
            });
            logFirestore("WRITE", 1);
        }
    }
}
