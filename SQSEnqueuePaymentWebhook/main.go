package main

import (
	"context"
	"encoding/json"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
)

var queueURL string

func init() {
	queueURL = os.Getenv("PAYMENT_WEBHOOK_QUEUE_URL")
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	payload := map[string]interface{}{
		"body":         req.Body,
		"queryStrings": req.QueryStringParameters,
	}

	msg, err := json.Marshal(payload)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, nil
	}

	sess := session.Must(session.NewSession())
	svc := sqs.New(sess)
	_, err = svc.SendMessage(&sqs.SendMessageInput{
		QueueUrl:    &queueURL,
		MessageBody: aws.String(string(msg)),
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, nil
	}

	return events.APIGatewayProxyResponse{StatusCode: 200}, nil
}

func main() {
	lambda.Start(handler)
}
