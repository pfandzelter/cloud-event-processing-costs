package uc1;

import com.google.auth.oauth2.GoogleCredentials;
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

public class Store implements HttpFunction, BackgroundFunction<Message> {
    private Firestore db;
    private final String collection;

    public Store() {
        // get environment variable COLLECTION
        this.collection = System.getenv("COLLECTION");
        // get environment variable PROJECT_ID
        String projectId = System.getenv("GOOGLE_CLOUD_PROJECT");

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
        System.out.printf("FIRESTORE OP %s: %d%n", operation, count);
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
        // step 2: store in Firestore
        try {
            db.collection(collection).add(map).get();
            logFirestore("WRITE", 1);
        } catch (Error | InterruptedException | ExecutionException ignored) {

        }
    }
}
