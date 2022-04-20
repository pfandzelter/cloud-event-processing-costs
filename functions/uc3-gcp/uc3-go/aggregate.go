package p

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"time"

	"cloud.google.com/go/firestore"
)

var selectCollection string = os.Getenv("SELECT_COLLECTION")
var windowSize int64
var interval int64

var projectID string = os.Getenv("GOOGLE_CLOUD_PROJECT")

func init() {
	var err error
	windowSize, err = strconv.ParseInt(os.Getenv("WINDOW_SIZE"), 10, 64)
	if err != nil {
		log.Fatalf("Failed to parse WINDOW_SIZE: %v", err)
	}

	interval, err = strconv.ParseInt(os.Getenv("INTERVAL"), 10, 64)
	if err != nil {
		log.Fatalf("Failed to parse INTERVAL: %v", err)
	}
}

var f *firestore.Client

func logFirestore(t string, count int) {
	fmt.Printf("FIRESTORE OP %s: %d\n", t, count)
}

func aggregate(data []byte) error {
	// parse JSON
	c := &struct {
		ID        string  `json:"identifier"`
		Value     float64 `json:"valueInW"`
		Timestamp int64   `json:"timestamp"`
	}{}
	if err := json.Unmarshal(data, c); err != nil {
		log.Printf("Failed to parse data: %v", err)
		return err
	}

	// select the attrbute we want
	id := c.ID
	i := c.Value

	// iterate over windows
	// this is not threadsafe at all, maybe it should be?

	// check the firestore collection
	if f == nil {
		var err error
		f, err = firestore.NewClient(context.Background(), projectID)
		if err != nil {
			log.Printf("Failed to create client: %v", err)
			return err
		}
	}

	now := time.Now().UTC().Unix()
	// iterate over all the entries (= open windows)
	// add values to open windows
	// close windows when they are deadlined
	// create new windows if required
	// there should be 2*windowSize/interval - 1 windows open at all times
	// offsets -windowsize+interval, -windowsize+2interval, ..., 0, interval, 2interval, ..., windowsize-interval
	//
	// - -|- - -
	//   -|- - - -
	//    |- - - - -|
	//    |  - - - -|-
	//    |    - - -|- -
	//    |      - -|- - -
	//    |        -|- - - -
	//    |         |- - - - -
	// 0 1|2 3 4 5 6 7 8 9 1 1
	//
	// Aggregation uc1 are based on https://guava.dev/releases/22.0/api/docs/com/google/common/math/StatsAccumulator.html
	// * count
	// * min
	// * max
	// * mean
	// * populationStandardDeviation

	for t := int64(0); t < windowSize; t += interval {
		// get the window
		wid := fmt.Sprintf("%s_%d", id, t)
		T := now - (now % windowSize) + int64(t)

		d := f.Collection(selectCollection).Doc(wid)

		doc, err := d.Get(context.Background())
		logFirestore("READ", 1)
		if err != nil {
			// create if it does not exist

			_, err := d.Set(context.Background(), map[string]interface{}{
				"T":     T,
				"Count": 1,
				"Min":   float64(i),
				"Max":   float64(i),
				"Mean":  float64(i),
				"SD":    0.0,
				"SD_M2": 0.0,
			})
			logFirestore("WRITE", 1)

			if err != nil {
				log.Printf("Failed to create window: %v", err)
				return err
			}

			doc, err = d.Get(context.Background())
			logFirestore("READ", 1)
			if err != nil {
				log.Printf("Failed to get window: %v", err)
				return err
			}
			continue
		}

		if doc.Data()["T"] == nil || doc.Data()["T"].(int64) == 0 {
			log.Printf("Failed to get window: T does not exist: %v", doc.Data()["T"])
			return err
		}

		if doc.Data()["T"].(int64) < now-windowSize {
			// window is dead

			// emit
			log.Printf("{\"time\":%d, \"sensor\": %s, \"count\": %d, \"min\": %.2f ,\"max\": %.2f, \"mean\": %.2f, \"sd\": %.2f }\n", T+t*interval, id, doc.Data()["Count"], doc.Data()["Min"], doc.Data()["Max"], doc.Data()["Mean"], doc.Data()["SD"])

			// reset window
			_, err = d.Set(context.Background(), map[string]interface{}{
				"T":     T,
				"Count": 1,
				"Min":   float64(i),
				"Max":   float64(i),
				"Mean":  float64(i),
				"SD":    0.0,
				"SD_M2": 0.0,
			})
			logFirestore("WRITE", 1)
			if err != nil {
				log.Printf("Failed to reset window: %v", err)
				return err
			}
			continue
		}

		var oldCount int64
		var oldMin float64
		var oldMax float64
		var oldMean float64
		var oldSDM2 float64

		if doc.Data()["Count"] != nil {
			oldCount = doc.Data()["Count"].(int64)
		}

		if doc.Data()["Min"] != nil {
			oldMin = doc.Data()["Min"].(float64)
		}

		if doc.Data()["Max"] != nil {
			oldMax = doc.Data()["Max"].(float64)
		}

		if doc.Data()["Mean"] != nil {
			oldMean = doc.Data()["Mean"].(float64)
		}

		if doc.Data()["SD_M2"] != nil {
			oldSDM2 = doc.Data()["SD_M2"].(float64)
		}

		// update window
		newCount := oldCount + 1
		newMin := math.Min(oldMin, i)
		newMax := math.Max(oldMax, i)
		newMean := (oldMean*float64(oldCount) + i) / float64(newCount)

		// https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm
		// no idea if this is correctly implemented
		delta := i - oldMean
		delta2 := i - (oldMean + delta/float64(oldCount))
		newSDM2 := oldSDM2 + delta*delta2

		newSD := math.Sqrt(newSDM2 / float64(newCount))

		_, err = d.Set(context.Background(), map[string]interface{}{
			"T":     doc.Data()["T"].(int64),
			"Count": newCount,
			"Min":   newMin,
			"Max":   newMax,
			"Mean":  newMean,
			"SD":    newSD,
			"SD_M2": newSDM2,
		})
		logFirestore("WRITE", 1)
		if err != nil {
			log.Printf("Failed to create window: %v", err)
			return err
		}
	}

	return nil
}

// UC3AggregateHTTP consumes a Pub/Sub message.
func UC3AggregateHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()
	data, err := ioutil.ReadAll(r.Body)

	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read body: %s", err.Error()), http.StatusInternalServerError)
	}

	err = aggregate(data)

	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to aggregate: %s", err.Error()), http.StatusInternalServerError)
	}
}
