package uc3;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.DynamoDB;
import com.amazonaws.services.dynamodbv2.document.Item;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;
import com.google.gson.Gson;

import java.util.Base64;
import java.util.Map;

public class Aggregate implements RequestHandler<Map, APIGatewayV2HTTPResponse> {
    private final DynamoDB db;
    private final String tableName;
    private final String region;
    private final int windowSize;
    private final int interval;

    public Aggregate() {
        // get environment variable TABLE_NAME
        this.tableName = System.getenv("TABLE_NAME");
        this.region = System.getenv("REGION");
        // get environment variable WINDOW_SIZE
        this.windowSize = Integer.parseInt(System.getenv("WINDOW_SIZE"));
        // get environment variable INTERVAL
        this.interval = Integer.parseInt(System.getenv("INTERVAL"));
        // connect to DynamoDB
        AmazonDynamoDB client = AmazonDynamoDBClientBuilder.standard().withRegion(region).build();
        this.db = new DynamoDB(client);
    }

    private void logDynamo(String operation, int count, String requestId) {
        System.out.printf("DYNAMO OP %s: %d (%s)\n", operation, count, requestId);
    }

    public APIGatewayV2HTTPResponse handleRequest(Map inputMap, Context context)
    {
        Map map;

        if (inputMap.get("body") != null) {
            String body = (String) inputMap.get("body");
            map = (Map) new Gson().fromJson(body, Map.class);
        } else {
            map = inputMap;
        }

        String requestId = context.getAwsRequestId();

        this.handle(map, requestId);

        APIGatewayV2HTTPResponse response = new APIGatewayV2HTTPResponse();
        response.setStatusCode(200);

        return response;
    }

    private void handle(Map map, String requestId) {

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

            long T = now - (now % windowSize) + t;

            Item d = db.getTable(tableName).getItem("identifier", id, "window", t);
            logDynamo("READ", 1, requestId);

            if (d == null) {
                // create a new document

                d = new Item()
                        .withPrimaryKey("identifier", id, "window", t)
                        .withNumber("T", T)
                        .withNumber("Count", 1)
                        .withNumber("Min", i)
                        .withNumber("Max", i)
                        .withNumber("Mean", i)
                        .withNumber("SD", 0.0)
                        .withNumber("SD_M2", 0.0);

                db.getTable(tableName).putItem(d);
                logDynamo("WRITE", 1, requestId);
                continue;
            }

            if (d.getNumber("T").longValue() < (now - windowSize)) {
                // window is dead
                System.out.printf(
                        "{\"time\":%s, \"sensor\": %s, \"count\": %s, \"min\": %s ,\"max\": %s, \"mean\": %s, \"sd\": %s }\n",
                        T + t * interval, id, d.get("Count"), d.get("Min"), d.get("Max"), d.get("Mean"),
                        d.get("SD"));

                d = new Item()
                        .withPrimaryKey("identifier", id, "window", t)
                        .withNumber("T", T)
                        .withNumber("Count", 1)
                        .withNumber("Min", i)
                        .withNumber("Max", i)
                        .withNumber("Mean", i)
                        .withNumber("SD", 0.0)
                        .withNumber("SD_M2", 0.0);

                db.getTable(tableName).putItem(d);
                logDynamo("WRITE", 1, requestId);
                continue;
            }

            int oldCount = 0;
            if (d.getNumber("Count") != null) {
                oldCount = d.getNumber("Count").intValue();
            }

            double oldMin = 0;
            if (d.getNumber("Min") != null) {
                oldMin = d.getNumber("Max").doubleValue();
            }

            double oldMax = 0;
            if (d.getNumber("Max") != null) {
                oldMax = d.getNumber("Max").doubleValue();
            }

            double oldMean = 0;
            if (d.getNumber("Mean") != null) {
                oldMean = d.getNumber("Mean").doubleValue();
            }

            double oldSDM2 = 0;
            if (d.getNumber("SD_M2") != null) {
                oldSDM2 = d.getNumber("SD_M2").doubleValue();
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

//            System.out.println("New values: \ncount: " + newCount + "\nmin: " + newMin + "\nmax: " + newMax + "\nmean: " + newMean + "\nsd: " + newSD + "\nsdm2: " + newSDM2);

            d = d.withNumber("Count", newCount)
                .withNumber("Min", newMin)
                .withNumber("Max", newMax)
                .withNumber("Mean", newMean)
                .withNumber("SD", newSD)
                .withNumber("SD_M2", newSDM2);

            db.getTable(tableName).putItem(d);
            logDynamo("WRITE", 1, requestId);
        }
    }
}
