The FocusMark AWS Infrastructure repository contains all of the core AWS infrastructure templates used to deploy the supporting resources that the FocusMark platform depends on.

The repository consists of mostly bash scripts and CloudFormation templates. It has been built and tested in a Linux environment. There should be very little work needed to deploy from macOS; deploying from Windows is not supported at this time but could be done with effort.

# Deploy

## Requirements

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html)

## Environment Variables
In order to run the deployment script you must have your environment set up with a few environment variables. The following table outlines the environment variables required with example values.

| Key                  | Value Type | Description | Examples                                           |
|----------------------|------------|-------------|----------------------------------------------------|
| deployed_environment | string     | The name of the environment you are deploying into | dev or prod |

In Linux or macOS environments you can set this in your `.bash_profile` file.

```
export deployed_environment=prod
```

The `deployed_environment` environment variable will be used in all of the names of the resources provisioned during deployment. Using the prod environment for example, the IAM Role created to grant API Gateway access to CloudWatch will be created as `focusmark-prod-role-apigateway_cloudwatch_integration`.

### IMPORTANT
The focusmark platform already uses dev, test and prod. Because of this they are not available as values for the `deployed_environment` environment variable. When the deployment script is executed the CloudFormation will fail due to the API Gateway custom domain already having been taken. It is recommended that you set the value of `deployed_environment` to your name + the environment you want ot deploy into.

## Infrastructure

The core infrastructure in this repository consists of the following:

- IAM Role granting API Gateway write access to CloudWatch logs
- Certificate for the API DNS
- API Gateway Custom Domain bound to the API DNS certificate
- Cognito UserPool for user account management and OAuth2/OpenID Connect
- Default Application Clients that have access to interact with the Cognito Userpool and OAuth/OIDC flows.

| Core Deployment | Identity Deployment |
|-----------------|---------------------|
| ![Core deployment process](/docs/aws-infrastructure-deployment-Core.png) | ![Identity deployment process](/docs/aws-infrastructure-deployment-Identity.png) |

## Deployment

In order to deploy the infrastructure you just need to execute the bash script included from a terminal:

```
$ sh deploy.sh
```

This will kick off the process and deploy the /core resources by executing the `/core/deploy.sh` script. It will then move on to deploying the Cognito and Identity bits by executing the `/identity/deploy.sh` script.

### IMPORTANT
During the initial deployment the `api-certificates.yaml` deployment will hang while CloudFormation waits for you to verify the DNS bound to the certificate.

You will need to add a CNAME to an existing Domain in order for the verification to happen. The CNAME records that need to be added can be seen in the Amazon Certificate Manager console. Once the CNAME is added for the Domain defined in the template along with the `SubjectAlternativeNames` then the CloudFormation template will continue to execute and complete.

When this is completed you will have a full Identity stack deployed for use. CloudFormation Stacks must be deleted in the order they were deployed, newest to oldest. CloudFormation will show you the order in which they were deployed in the AWS Console.

# Dependencies

This repository is responsible for creating the application clients and resource servers used by the APIs on the platform. As new APIs are on-boarded this repository needs to be updated to include new resource servers for the resources exposed by any newly deployed APIs.

All deployments via CF and SAM that require uploading and storing in S3, regardless of repository, should use the deployment S3 bucket provisioned as part of the core infrastructure found in this repository.

# Usage

## Creating accounts and fetching Tokens
You can now fetch tokens by creating a new user account and requesting a set of tokens.

To get started, go to the AWS Cognito Console and take note of the ClientId and ClientSecret created for the `Postman Client`. Create a new request in [Postman](https://getpostman.com) and select the `Authorization` tab. Set the type to `OAuth 2.0` and then select _Get New Access Token_

![Authorization](/docs/postman-client-001.png)

Enter the Auth URL as the Domain created when the UserPool deployment happened. By default the domain is:

> https://focusmark-${deployed_environment}-identity.auth.us-east-1.amazoncognito.com/login

You will need to substitute the `${deployed_environment}` with the environment value you set in the environment variables prior to deploying.

Access Token URL will follow the same naming convention, with a different Route.

> https://focusmark-local-identity.auth.us-east-1.amazoncognito.com/oauth2/token

Enter the Client Id and Client Secret found in the AWS Cognito Console for the Postman App. For Scopes, enter `openid`. For the Callback URL enter:

> https://${deployed_environment}.identity.focusmark.app

Your should look similar, with the Client Id and Client Secrets filled in.

![Authorization](/docs/postman-client-002.png)

This will navigate you to the Cognito custom domain and present the hosted UI for account sign-in. 

![Authorization](/docs/postman-client-003.png)

Since you won't have an account initially, click the Sign Up link instead. Enter the information asked for and click Sign up

![Authorization](/docs/postman-client-004.png)

You will be prompted to go in to your email and click the confirmation link email that was sent to you. 

![Authorization](/docs/postman-client-005.png)

If you entered a valid email address then you will see an email like the following in your mail box:

![Authorization](/docs/postman-client-009.png)

Click the link to verify the account. If you did not enter a valid email address then you will have to manually confirm your account within Cognito. To do this, go into the Users and Groups section, and find your new user account:

![Authorization](/docs/postman-client-006.png)

Select your user account and then select the Confirm User:

![Authorization](/docs/postman-client-007.png)

Once you have confirmed your account go back to Postman and click the Continue button: 

![Authorization](/docs/postman-client-005.png)

This will complete the `authorization_code` flow that is used and produce a set of tokens.

![Authorization](/docs/postman-client-008.png)

You will receive the `access_token` and a `refresh_token`. Since we specified `openid` as a Scope you will also receive an `identity_token`. You can take the `acess_token` or the `identity_token` and paste them into [Jwt IO](https://jwt.io) to see what they look like.

# Details
> TODO: Discuss adding clients, authorizing APIs in a "hook" in pattern and why usernames over emails, why emails are not in access_tokens and linking data records back to a user via 'sub' and not username or email.