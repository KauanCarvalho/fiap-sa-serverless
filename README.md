# FiAP SA Serverless Architecture

## 🌐 Represetação da comunicação entre os serviços

Abaixo está o diagrama representando a comunicação entre os principais componentes da arquitetura (Lambda, API Gateway e SQS).

```mermaid
flowchart TD
  subgraph API_Gateway["API Gateway"]
    POST_Webhook(["POST - /prod/webhook_events"])
    POST_SignUp(["POST - /signup"])
    POST_Login(["POST - /login"])
    POST_Checkout(["POST - /checkout"])
  end

  subgraph Lambda["Lambda"]
    SQSEnqueuePaymentWebhook(["SQSEnqueuePaymentWebhook"])
    UserAuth(["UserAuth"])
    UserLogin(["UserLogin"])
    CheckoutHandler(["CheckoutHandler"])
  end

  subgraph Messaging_Layer["Messaging Layer"]
    SQS_Payment{{Queue: fiap_sa_payment_service_webhook_events}}
  end

  subgraph CognitoLayer["CognitoLayer"]
    Cognito{{PoolID}}
  end

  subgraph Services["Services"]
    subgraph Payment["fiap-sa-payment-service"]
      Payment_Worker["Worker"]
    end

    subgraph Order["fiap-sa-order-service"]
      Order_API["API"]
    end
  end

  POST_Webhook --> SQSEnqueuePaymentWebhook
  SQSEnqueuePaymentWebhook --> SQS_Payment
  SQS_Payment --> Payment_Worker
  POST_SignUp --> UserAuth
  UserAuth --> Cognito
  UserAuth --> Order_API
  POST_Login --> UserLogin
  UserLogin --> Cognito
  POST_Checkout --> CheckoutHandler
  CheckoutHandler --> Cognito
  CheckoutHandler --> Order_API
```

Este repositório descreve a infraestrutura e o código da função **Lambda** responsável por processar eventos de Webhook no serviço de pagamentos, com integração ao **API Gateway** e filas **SQS** para orquestração de mensagens. A infraestrutura é gerida com **Terraform** e a função Lambda é escrita em [GO](./SQSEnqueuePaymentWebhook/main.go).

## 📦 Arquitetura

A arquitetura é composta por vários componentes importantes:

- **AWS Lambda**: A função Lambda processa eventos recebidos via **API Gateway** e publica dados em uma fila **SQS**.
- **API Gateway**: Expõe uma rota `POST /prod/webhook_events` que recebe eventos e invoca a função Lambda.
- **SQS (Simple Queue Service)**: Utilizado para armazenar e processar eventos de webhook e mensagens de eventos de pagamento.
- **IAM**: Role do IAM é utilizada para conceder permissões apropriadas à função Lambda.
- **Cognito**: Responsável pela autenticação, autorização e gerenciamento de usuários do ecossistema, permitindo o cadastro de usuários, login, recuperação de senha e controle de acesso usando provedores de identidade (como e-mail/senha ou redes sociais). E com as credenciais geradas, fechar um pedido.

## 📁 Estrutura do Projeto

A estrutura de diretórios do projeto é a seguinte:

```
├── production/terraform/              # Infraestrutura gerida pelo Terraform
│   ├── ...
│   ├── webhook.tf                     # Terraform da função lambda de webhook.
|   └── user_auth.tf                   # Terraform das funções lambdas de autenticação e autorização.
├── test/                              # Scripts de teste
│   └── test-webhook.sh                # Script para testar a API de Webhook
|   └── test-auth-layer.sh             # Testes da camada de autorização de produção.
├── CheckoutHandler/                   # Código da lambda do checkout.
├── UserAuth/                          # Código da lambda de criação de clientes.
├── UserLogin/                         # Código da lambda de login de clientes.
├── SQSEnqueuePaymentWebhook/           # Código da lambda de webhooks.
├── Makefile                           # Arquivo de automação para build e deploy
```

## ☁️ Infraestrutura de Produção

A infraestrutura é configurada com **Terraform** e inclui os seguintes recursos:

1. **AWS Lambda**:
   - Função Lambda para processar os eventos do Webhook.
   - Integração com o **API Gateway** para exposição da API.
   - Publicação de eventos para a fila **SQS**.
   
2. **API Gateway**:
   - Rota `POST /webhook_events` exposta para o recebimento de eventos de pagamento.

3. **SQS (Simple Queue Service)**:
   - **SQS Payment Webhook Events**: Fila onde os eventos de Webhook serão enviados.

4. **IAM Role**:
   - Permite que a Lambda acesse recursos como SQS e o API Gateway.

5. **Cognito**:
   - Camada de autenticação e autorização dos usuários.

> 🛑 **Importante:**  
> O Terraform **não é executado localmente**.  
> Todos os planos e execuções (`apply`) são realizados via **Terraform Cloud**, acionados através de **pipelines CI/CD** (GitHub Actions).

## Funcionalidade

### Webhook de Pagamento

A função Lambda é acionada por eventos recebidos via **API Gateway**. Esses eventos são processados e publicados na fila **SQS** para serem consumidos posteriormente.

### Camada de autenticação

API Gateway + Lambda para criar, logar, e fechar um pedido para um cliente.

### Testes

O script `test/test-webhook.sh` é utilizado para testar os cenários do webhook. Ele realiza chamadas para o endpoint do **API Gateway** para garantir que o fluxo de integração funcione corretamente.

O script `test/test-auth-layer.sh` é utilizado para testar os cenários de autenticação e autorização do cliente, interagindo diretamente com o cluster e cognito.

### Makefile

O **Makefile** é utilizado para automatizar o processo de build, zipagem e execução de testes da função Lambda.

#### Comandos:

- `make build-webhook`: Compila a função Lambda para o ambiente Linux.
- `make zip-webhook`: Empacota a função Lambda em um arquivo `.zip` para deploy.
- `make test-prod`: Executa os testes, aceitando parâmetros como o endpoint do webhook a ser testado.

## Como Usar

### Pré-requisitos

- **Go**: Para compilar a função Lambda.
- **Make**: Para automação das tarefas.

### Deploy da Função Lambda

1. Navegue até o diretório `SQSEnqueuePaymentWebhook/` (ou qualquer outra lambda).
2. Compile a função Lambda utilizando o comando:

    ```bash
    make build-webhook # Existem outros, basta olha no Makefile
    ```

3. Faça o deploy da função Lambda criando o pacote `.zip`:

    ```bash
    make zip-webhook
    ```
4. Abra um PR e approve o plano de alterações no terraform cloud.

### Testando o Webhook

1. Navegue até o diretório `test/`.
2. Execute o script `test-webhook.sh` para testar a API de webhook:

    ```bash
    ./test/test-webhook.sh <webhook_url>
    ```

OU

    ```bash
    make test-webhook-api-gateway <webhook_url>
    ```

### Testando a Camada de auteticação e aturização:

1. Navegue até o diretório `test/`.
2. Execute o script `test-auth-layer.sh` para testar as API de autenticação:

    ```bash
    ./test/test-auth-layer.sh <webhook_url>
    ```

OU

  ```bash
    make test-auth-layer <webhook_url> <sku1> <sku2> ...
    ```
