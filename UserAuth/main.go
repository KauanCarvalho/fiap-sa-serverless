package main

import (
	"bytes"
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

type ClientResponse struct {
	ID int `json:"id"`
}

func handler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	var signupReq SignupRequest
	if err := json.Unmarshal([]byte(request.Body), &signupReq); err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusBadRequest, Body: "Invalid request body"}, nil
	}

	sess := session.Must(session.NewSession())
	svc := cognitoidentityprovider.New(sess)

	clientID := os.Getenv("COGNITO_CLIENT_ID")
	userPoolID := os.Getenv("COGNITO_USER_POOL_ID")

	signupInput := &cognitoidentityprovider.SignUpInput{
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

	_, err := svc.SignUp(signupInput)
	if err != nil {
		log.Println("Signup failed:", err)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: fmt.Sprintf("Signup error: %s", err.Error())}, nil
	}

	confirmInput := &cognitoidentityprovider.AdminConfirmSignUpInput{
		UserPoolId: aws.String(userPoolID),
		Username:   aws.String(signupReq.CPF),
	}

	_, err = svc.AdminConfirmSignUp(confirmInput)
	if err != nil {
		log.Println("Admin confirm signup failed:", err)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: fmt.Sprintf("Confirm signup error: %s", err.Error())}, nil
	}

	apiURL := os.Getenv("API_URL")
	clientData := map[string]string{
		"name": signupReq.CPF,
		"cpf":  signupReq.CPF,
	}

	clientJSON, _ := json.Marshal(clientData)

	req, err := http.NewRequest(http.MethodPost, apiURL+"/api/v1/clients", bytes.NewBuffer(clientJSON))
	if err != nil {
		deleteUser(svc, userPoolID, signupReq.CPF)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: "Request error"}, nil
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		deleteUser(svc, userPoolID, signupReq.CPF)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: "API call failed"}, nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		deleteUser(svc, userPoolID, signupReq.CPF)
		return events.APIGatewayV2HTTPResponse{StatusCode: resp.StatusCode, Body: "API call failed to create client"}, nil
	}

	var clientResp ClientResponse
	if err := json.NewDecoder(resp.Body).Decode(&clientResp); err != nil {
		deleteUser(svc, userPoolID, signupReq.CPF)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: "Error parsing client data"}, nil
	}

	updateInput := &cognitoidentityprovider.AdminUpdateUserAttributesInput{
		UserPoolId: aws.String(userPoolID),
		Username:   aws.String(signupReq.CPF),
		UserAttributes: []*cognitoidentityprovider.AttributeType{
			{
				Name:  aws.String("custom:client_id"),
				Value: aws.String(fmt.Sprintf("%d", clientResp.ID)),
			},
		},
	}

	_, err = svc.AdminUpdateUserAttributes(updateInput)
	if err != nil {
		deleteUser(svc, userPoolID, signupReq.CPF)
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError, Body: fmt.Sprintf("Failed to update user with client ID: %s", err.Error())}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: http.StatusOK,
		Body:       "User signed up and client ID added successfully",
	}, nil
}

func deleteUser(svc *cognitoidentityprovider.CognitoIdentityProvider, userPoolID, username string) {
	_, err := svc.AdminDeleteUser(&cognitoidentityprovider.AdminDeleteUserInput{
		UserPoolId: aws.String(userPoolID),
		Username:   aws.String(username),
	})
	if err != nil {
		log.Printf("Failed to delete user from Cognito: %s", err)
	}
}

func main() {
	lambda.Start(handler)
}
