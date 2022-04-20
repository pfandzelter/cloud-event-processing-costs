package uc1;

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

public class Store implements RequestHandler<Map, APIGatewayV2HTTPResponse> {
    private final DynamoDB db;
    private final String tableName;
    private final String region;

    public Store() {
        // get environment variable TABLE_NAME
        this.tableName = System.getenv("TABLE_NAME");
        this.region = System.getenv("REGION");

        // connect to DynamoDB
        AmazonDynamoDB client = AmazonDynamoDBClientBuilder.standard().withRegion(region).build();
        this.db = new DynamoDB(client);
    }

    private void logDynamo(String operation, int count, String requestId) {
        System.out.printf("DYNAMO OP %s: %d (%s)\n", operation, count, requestId);
    }

    @Override
    public APIGatewayV2HTTPResponse handleRequest(Map inputMap, Context context)
    {
//        System.out.println("Received: " + inputMap);

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
        // store entry in DynamoDB
        Item item = new Item();

        int timestamp = 0;
        double valueInW = 0;

        if (map.get("timestamp").getClass() == Integer.class) {
            timestamp = (int) map.get("timestamp");
        } else if (map.get("timestamp").getClass() == Double.class) {
            timestamp = (int) (double) map.get("timestamp");
        }

        if (map.get("valueInW").getClass() == Integer.class) {
            valueInW = (int) map.get("valueInW");
        } else if (map.get("valueInW").getClass() == Double.class) {
            valueInW = (double) map.get("valueInW");
        }

        item.withPrimaryKey("identifier", map.get("identifier"))
                .withNumber("timestamp", timestamp)
                .withNumber("valueInW", valueInW);

        db.getTable(tableName).putItem(item);
        logDynamo("WRITE", 1, requestId);
    }
}
