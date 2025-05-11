package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider"
	cognitoidentityprovidertypes "github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider/types"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var (
	orderServiceBaseURL string
	cognitoClient       *cognitoidentityprovider.Client
	userPoolID          string
	clientID            string
	secretKey           string
)

type Client struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	CPF       string `json:"cpf"`
	CreatedAt string `json:"created_at"`
}

type CheckoutRequest struct {
	Items []struct {
		SKU      string `json:"sku"`
		Quantity int    `json:"quantity"`
	} `json:"items"`
}

func init() {
	orderServiceBaseURL = os.Getenv("ORDER_SERVICE_BASE_URL")
	userPoolID = os.Getenv("COGNITO_USER_POOL_ID")
	clientID = os.Getenv("COGNITO_CLIENT_ID")
	secretKey = os.Getenv("SECRET_KEY")

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("failed to load AWS config: %v", err)
	}
	cognitoClient = cognitoidentityprovider.NewFromConfig(cfg)
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	switch {
	case req.HTTPMethod == "POST" && req.Path == "/auth":
		return handleAuth(req)
	case req.HTTPMethod == "GET" && req.Path == "/user":
		return handleUser(req)
	default:
		return response(404, map[string]string{"error": "Route not found"}), nil
	}
}

func handleAuth(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var data map[string]string
	_ = json.Unmarshal([]byte(req.Body), &data)
	cpf := data["cpf"]
	if cpf == "" {
		return response(400, map[string]string{"error": "CPF is required"}), nil
	}

	resp, err := http.Get(fmt.Sprintf("%s/api/v1/clients/%s", orderServiceBaseURL, cpf))
	if err != nil || resp.StatusCode == 500 {
		return response(500, map[string]string{"error": "Error on user searching"}), nil
	}

	var client Client
	if resp.StatusCode == 404 {
		cID, err := createClient(cpf)
		if err != nil {
			return response(500, map[string]string{"error": "Error creating client"}), nil
		}

		_, err = cognitoClient.AdminCreateUser(context.TODO(), &cognitoidentityprovider.AdminCreateUserInput{
			UserPoolId: &userPoolID,
			Username:   &cpf,
			UserAttributes: []cognitoidentityprovidertypes.AttributeType{{
				Name:  aws.String("custom:client_id"),
				Value: aws.String(fmt.Sprint(cID)),
			}},
			MessageAction: "SUPPRESS",
		})
		if err != nil {
			return response(500, map[string]string{"error": "Error o creating user on cogito"}), nil
		}

		client.ID = cID
	} else if resp.StatusCode == 200 {
		if err := json.NewDecoder(resp.Body).Decode(&client); err != nil {
			return response(500, map[string]string{"error": "Error parsing client data"}), nil
		}
	} else {
		return response(500, "Error fetching client data"), nil
	}

	claims := jwt.MapClaims{
		"client_id": client.ID,
		"cpf":       cpf,
		"exp":       time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	tokenString, err := token.SignedString([]byte(secretKey))
	if err != nil {
		return response(500, map[string]string{"error": "Error signing JWT"}), nil
	}

	return response(200, map[string]string{"token": tokenString}), nil
}

func handleUser(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	tokenStr := req.Headers["Authorization"]
	if tokenStr == "" {
		return response(401, "Unauthorized: Missing Authorization header"), nil
	}

	claims, err := parseJWT(tokenStr)
	if err != nil {
		return response(401, "Unauthorized: Invalid token"), nil
	}

	return response(200, claims), nil
}

func response(code int, payload interface{}) events.APIGatewayProxyResponse {
	b, _ := json.Marshal(payload)
	return events.APIGatewayProxyResponse{StatusCode: code, Body: string(b)}
}

func parseJWT(authHeader string) (map[string]interface{}, error) {
	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return []byte(secretKey), nil
	})
	if err != nil || !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}

	if claims, ok := token.Claims.(jwt.MapClaims); ok {
		return claims, nil
	}
	return nil, fmt.Errorf("invalid token claims")
}

func createClient(cpf string) (int, error) {
	clientName := fmt.Sprintf("name-%s", uuid.NewString())
	client := map[string]interface{}{"cpf": cpf, "name": clientName}
	clientJSON, err := json.Marshal(client)
	if err != nil {
		return 0, fmt.Errorf("failed to marshal client data: %v", err)
	}

	resp, err := http.Post(fmt.Sprintf("%s/api/v1/clients", orderServiceBaseURL), "application/json", strings.NewReader(string(clientJSON)))
	if err != nil {
		return 0, fmt.Errorf("failed to create client: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 201 {
		return 0, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var createdClient Client
	if err := json.NewDecoder(resp.Body).Decode(&createdClient); err != nil {
		return 0, fmt.Errorf("failed to decode response body: %v", err)
	}

	return createdClient.ID, nil
}

func main() {
	lambda.Start(handler)
}
