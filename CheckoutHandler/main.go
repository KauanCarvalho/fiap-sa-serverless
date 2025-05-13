package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

var (
	apiURL = os.Getenv("API_URL")
)

type CheckoutItem struct {
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}

type CheckoutRequest struct {
	CognitoID string         `json:"cognito_id"`
	Items     []CheckoutItem `json:"items"`
}

func handler(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	claims := req.RequestContext.Authorizer.JWT.Claims

	sub, ok := claims["sub"]
	if !ok {
		return response(400, "Invalid token: missing sub"), nil
	}

	var checkoutReq CheckoutRequest
	if err := json.Unmarshal([]byte(req.Body), &checkoutReq); err != nil {
		return response(400, "Invalid JSON"), nil
	}

	checkoutReq.CognitoID = sub

	outReqBody, _ := json.Marshal(checkoutReq)
	resp, err := http.Post(apiURL+"/api/v1/checkout", "application/json", bytes.NewReader(outReqBody))
	if err != nil {
		return response(502, "Error to connect with order service"), nil
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)

	return events.APIGatewayV2HTTPResponse{
		StatusCode: resp.StatusCode,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(bodyBytes),
	}, nil
}

func response(status int, msg string) events.APIGatewayV2HTTPResponse {
	return events.APIGatewayV2HTTPResponse{
		StatusCode: status,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       `{"message": "` + msg + `"}`,
	}
}

func main() {
	lambda.Start(handler)
}
