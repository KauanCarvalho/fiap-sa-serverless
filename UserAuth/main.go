package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cognitoidentityprovider"
)

type SignupRequest struct {
	CPF      string `json:"cpf"`
	Password string `json:"password"`
}

func handler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	var signupReq SignupRequest
	if err := json.Unmarshal([]byte(request.Body), &signupReq); err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusBadRequest, Body: "Invalid request body"}, nil
	}

	sess := session.Must(session.NewSession())
	svc := cognitoidentityprovider.New(sess)

	clientID := os.Getenv("COGNITO_CLIENT_ID")

	input := &cognitoidentityprovider.SignUpInput{
		ClientId: aws.String(clientID),
		Username: aws.String(signupReq.CPF),
		Password: aws.String(signupReq.Password),
		UserAttributes: []*cognitoidentityprovider.AttributeType{
			{
				Name:  aws.String("custom:cpf"),
				Value: aws.String(signupReq.CPF),
			},
		},
	}

	_, err := svc.SignUp(input)
	if err != nil {
		log.Println("Signup failed:", err)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: fmt.Sprintf("Signup error: %s", err.Error())}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: http.StatusOK,
		Body:       "User signed up successfully",
	}, nil
}

func main() {
	lambda.Start(handler)
}
