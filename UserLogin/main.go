package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cognitoidentityprovider"
)

type LoginRequest struct {
	CPF      string `json:"cpf"`
	Password string `json:"password"`
}

type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	IDToken      string `json:"id_token"`
	RefreshToken string `json:"refresh_token"`
}

func handler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	var loginReq LoginRequest
	if err := json.Unmarshal([]byte(request.Body), &loginReq); err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusBadRequest, Body: "Invalid request body"}, nil
	}

	clientID := os.Getenv("COGNITO_CLIENT_ID")
	sess := session.Must(session.NewSession())
	svc := cognitoidentityprovider.New(sess)

	authInput := &cognitoidentityprovider.InitiateAuthInput{
		AuthFlow: aws.String("USER_PASSWORD_AUTH"),
		ClientId: aws.String(clientID),
		AuthParameters: map[string]*string{
			"USERNAME": aws.String(loginReq.CPF),
			"PASSWORD": aws.String(loginReq.Password),
		},
	}

	authResp, err := svc.InitiateAuth(authInput)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: http.StatusUnauthorized,
			Body:       fmt.Sprintf("Login failed: %s", err.Error()),
		}, nil
	}

	tokens := authResp.AuthenticationResult
	respBody, _ := json.Marshal(LoginResponse{
		AccessToken:  aws.StringValue(tokens.AccessToken),
		IDToken:      aws.StringValue(tokens.IdToken),
		RefreshToken: aws.StringValue(tokens.RefreshToken),
	})

	return events.APIGatewayV2HTTPResponse{
		StatusCode: http.StatusOK,
		Body:       string(respBody),
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
	}, nil
}

func main() {
	lambda.Start(handler)
}
