# FocusMark Identity and Auth

This repository contains all of the core AWS CloudFormation templates used to deploy the supporting resources that the FocusMark platform depends on for identity and auth.

The repository consists of mostly bash scripts and CloudFormation templates. It has been built and tested in a Linux environment. There should be very little work needed to deploy from macOS; deploying from Windows is not supported at this time but could be done with effort.

> TODO: Discuss adding clients, authorizing APIs in a "hook" in pattern and why usernames over emails, why emails are not in access_tokens and linking data records back to a user via 'sub' and not username or email.

# Deploy

## Requirements

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html)
- [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

## Optional
- [cfn-lint](https://github.com/aws-cloudformation/cfn-python-lint)

## Environment Variables
In order to run the deployment script you must have your environment set up with a few environment variables. The following table outlines the environment variables required with example values.

| Key                  | Value Type | Description | Examples                                           |
|----------------------|------------|-------------|----------------------------------------------------|
| deployed_environment | string     | The name of the environment you are deploying into | dev or prod |
| focusmark_productname | string | The name of the product. You _must_ use the name of a Domain that you own. | SuperTodo |

In Linux or macOS environments you can set this in your `.bash_profile` file.

```
export deployed_environment=dev
export focusmark_productname=supertodo

PATH=$PATH:$HOME/.local/bin:$HOME/bin
```

once your `.bash_profile` is set you can refresh the environment

```
$ source ~/.bash_profile
```

The `deployed_environment` and `focusmark_productname` environment variables will be used in all of the names of the resources provisioned during deployment. Using the `prod` environment and `supertodo` as the product name for example, the Cognito UserPool created will be called `supertodo-prod-userpool-customers`.


## Infrastructure

The core infrastructure in this repository consists of the following:

- Certificate for the auth sub-domain
- Cognito UserPool for user account management and OAuth2/OpenID Connect
- Default Application Clients that have access to interact with the Cognito Userpool and OAuth/OIDC flows.
- Resource Servers for the Project and Task APIs.

![Resources](/docs/identity-infrastructure_resources.jpeg)

## Deployment

In order to deploy the infrastructure you just need to execute the bash script included from a terminal:

```
$ sh deploy.sh
```

This will kick off the process and deploy the resources in each CloudFormation template.

### IMPORTANT
During the initial deployment the `api-certificates.yaml` deployment will hang while CloudFormation waits for you to verify the DNS bound to the certificate. If your Domain is managed by Route 53 (registered via Route 53, or purchased at another Registrar but Nameservers set to Route 53) then the verification can be done automatically. Otherwise, you must manually verify.

You will need to add a CNAME to an existing Domain in order for the verification to happen. The CNAME records that need to be added can be seen in the Amazon Certificate Manager console. Once the CNAME is added for the Domain defined in the template along with the `SubjectAlternativeNames` then the CloudFormation template will continue to execute and complete.

### Stack deployment order

The following diagram shows the order in which the CloudFormation Stacks are deployed.

![Resources](/docs/identity-infrastructure_deploy-process.jpeg)

When this is completed you will have a full Identity stack deployed for use. CloudFormation Stacks must be deleted in the order they were deployed, newest to oldest. CloudFormation will show you the order in which they were deployed in the AWS Console.

# Dependencies

This repository is responsible for creating the application clients and resource servers used by the APIs on the platform. As new APIs are on-boarded this repository needs to be updated to include new resource servers for the resources exposed by any newly deployed APIs.

All deployments via CF and SAM that require uploading and storing in S3, regardless of repository, should use the deployment S3 bucket provisioned as part of the core infrastructure found in the [AWS Infrastructure](https://github.com/FocusMark/auth-infrastructure) Repository.

# Usage

## Creating accounts and fetching Tokens
You can now fetch tokens by creating a new user account and requesting a set of tokens. This can be done from the web-browser by browsing to the https://{productName-targetEnvironment.auth.us-east-1.amazoncognito.com URL. Substitute the `productName` and `targetEnvironment` part of the URL with the values you provided as environment variables to the CloudFormation deployment scripts. For example, if productName was _supertodo_ and the environment was _test_ then your URL will be https://supertodo-test.auth.us-east-1.amazoncognito.com.

In order to land on the login page you must provide a series of parameters in the URL query string. The following table defines what those parameters are. The parameters must be provided exactly as shown in the table as they are case-sensitive.

| parameter | expected value |
|-----------|----------------|
| client_id | Client Id for the client accessing the login page. For testing you can find the Postman Client Id in the Cognito UserPool console page in AWS |
| client_secret | If a Client Secret is required by the Client chosen above then you must provide it. The Postman Client for instance requires a Secret. |
| redirect_uri | This is defined by the Client being used. For example, Postman client requires a value of https://{targetEnvironment}-auth.{productName}.app
| response_type | The literal value of `code` |
| scopes | Supported Scopes are: `openid`, `app.supertodo.api.project/project.read`, `app.supertodo.api.project/project.write`, `app.supertodo.api.project/project.delete`, `app.supertodo.api.task/task.write`, `app.supertodo.api.task/task.write` and `app.supertodo.api.task/task.delete` |

The scopes indicate what you want to do with the API. For example, if you don't include `app.supertodo.api.task/task.read` but you do include `app.supertodo.api.task/task.write` then you will be allowed to create new Tasks but you will not be allwoed to query for them.

An example URL with all of the above parameters added to the Query String, assuming a `productName` and `targetEnvironment` of _supertodo_ and _test_ - your URL would be:

https://supertodo-test.auth.us-east-1.amazoncognito.com/login?client_id=123456789&client_secret=abcdefghijklmnopqrstuvwxyz&redirect_uri=https://test-auth.supertodo.app&response_type=code&scopes=openid+app.supertodo.api.project/project.read+app.supertodo.api.project/project.write+app.supertodo.api.project/project.delete+app.supertodo.api.task/task.delete

![Login](/docs/login-ui.png)

You may select _Sign up_ at the bottom to create a new account. 

![Sign Up](/docs/signup-ui.png)

When you create a new account an email confirmation will be sent to the email address provided.

![Sign Up](/docs/signup-verification.png)

You can click the link in the email and it redirect you back to the auth page notifying you that your account has been confirmed. You can return to the login page and enter your credentials. Upon logging into your account you will be redirected to a page saying _This site can't be reached_. This is ok - if you look at the URL bar you will notice a new query string parameter has been given to you. The parameter is `code` and the value is a 1-time code you can use. This code can be exchanged for an `access token` that can be used to authorize your REST requests.

You can take this code and make a CURL request to a new URL - https://{productName}-{targetEnvironment}.auth.us-east-1.amazoncognito.com/oauth2/token.

You will need to make the CURL request a POST with a body that is formatted as `x-www-form-urlencoded`. The body must contain the following parameters:

| parameter | expected value |
|-----------|----------------|
| client_id | Client Id for the client accessing the login page. For testing you can find the Postman Client Id in the Cognito UserPool console page in AWS |
| client_secret | If a Client Secret is required by the Client chosen above then you must provide it. The Postman Client for instance requires a Secret. |
| redirect_uri | This is defined by the Client being used. For example, Postman client requires a value of https://{targetEnvironment}-auth.{productName}.app
| code | The value of the `code` given after you logged in. |
| grant_type | The literal value of `authorization_code` |

An example CURL request would look like this: 

```
curl --location --request POST 'https://supertodo-test.auth.us-east-1.amazoncognito.com/oauth2/token' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'code=abcdefg-abcd-abcd-abcd-12345678' \
--data-urlencode 'grant_type=authorization_code' \
--data-urlencode 'client_id=123456789' \
--data-urlencode 'client_secret=abcdefghijklmnop' \
--data-urlencode 'redirect_uri=https://test-auth.supertodo.app'
```

After you make this request you will receive the following JSON payload containing your Access key, Refresh Token and Id Token.

```
{
    "id_token": "eyJraWQiOiJQ.....",
    "access_token": "eyJraWQiOiJ......",
    "refresh_token": "eyJjdHkiOiJK.....",
    "expires_in": 3600,
    "token_type": "Bearer"
}
```

## Postman

You can configure Postman to automate this process for you. This is done by setting the Authorization of a Postman request to OAuth 2.0 and using a **Header Prefix** of `Bearer`.

![Postman Request](/docs/login-postman-auth-ui.png)

You can then select the **Get New Access Token** button to launch the auth config. Enter the values into the fields that you would have manually provided via query strings as shown above.

![Postman Auth Config](/docs/login-postman-auth-config.png)

You can then request a new token and use it on any of the FocusMark APIs.