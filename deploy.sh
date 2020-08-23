if [ -z "$deployed_environment" ]
    then 
        echo "\$deployed_environment environment variable is unset!"
        echo "Aborting deployment."
        exit
fi

product_name=$focusmark_productname
cd src

# Deploy certificates
certificates_template='auth-certificates.yaml'
certificates_stackname=$product_name-"$deployed_environment"-cf-auth-certificates
echo Deploying the $certificates_stackname stack into $deployed_environment

aws cloudformation deploy \
    --template-file $certificates_template \
    --stack-name $certificates_stackname \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        TargetEnvironment=$deployed_environment \
        ProductName=$product_name

# UserPool deployment
stack_name_identity=$product_name-"$deployed_environment"-cf-auth-customeridentity
template_file_identity='identity.yaml'

echo Deploying the $stack_name_identity stack into $deployed_environment
aws cloudformation deploy \
    --template-file $template_file_identity \
    --stack-name $stack_name_identity \
    --parameter-overrides \
        TargetEnvironment=$deployed_environment \
        ProductName=$product_name

# UserPool Resource Servers. This Stack must exist before Client Apps can be deployed as they depend on the Scopes defined in the Resource Server Stack.
stack_name_resource_servers=$product_name-"$deployed_environment"-cf-auth-resourceservers
template_file_resource_servers='resource-servers.yaml'

echo Deploying the $stack_name_resource_servers stack into $deployed_environment
aws cloudformation deploy \
    --template-file $template_file_resource_servers \
    --stack-name $stack_name_resource_servers \
    --parameter-overrides \
        TargetEnvironment=$deployed_environment \
        ProductName=$product_name

# Client Apps deployment
stack_name_client_apps=$product_name-"$deployed_environment"-cf-auth-clientapps
template_file_client_apps='client-apps.yaml'

echo Deploying the $stack_name_client_apps stack into $deployed_environment
aws cloudformation deploy \
    --template-file $template_file_client_apps \
    --stack-name $stack_name_client_apps \
    --parameter-overrides \
        TargetEnvironment=$deployed_environment \
        ProductName=$product_name