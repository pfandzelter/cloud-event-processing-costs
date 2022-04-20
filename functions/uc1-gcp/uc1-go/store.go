package p

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"cloud.google.com/go/firestore"
)

var collection string = os.Getenv("COLLECTION")
var projectID string = os.Getenv("GOOGLE_CLOUD_PROJECT")

var f *firestore.Client

func logFirestore(t string, count int) {
	fmt.Printf("FIRESTORE OP %s: %d\n", t, count)
}

func store(data []byte) error {
	// parse JSON
	var c map[string]interface{}
	if err := json.Unmarshal(data, &c); err != nil {
		return err
	}

	// write it to firestore
	if f == nil {
		var err error
		f, err = firestore.NewClient(context.Background(), projectID)
		if err != nil {
			log.Printf("Failed to create client: %v", err)
			return err
		}
	}

	_, _, err := f.Collection(collection).Add(context.Background(), c)
	logFirestore("WRITE", 1)

	if err != nil {
		log.Printf("Failed adding: %v", err)
		return err
	}

	return nil
}

// UC1StoreHTTP answers HTTP API requests.
func UC1StoreHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()
	data, err := ioutil.ReadAll(r.Body)

	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read body: %s", err.Error()), http.StatusInternalServerError)
	}

	err = store(data)

	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to store: %s", err.Error()), http.StatusInternalServerError)
	}
}
