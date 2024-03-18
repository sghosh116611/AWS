import boto3
import json


def lambda_handler(event, context):

    ec2_client = boto3.client("ec2")

    config = json.loads(event['invokingEvent'])
    configuration_item = config["configurationItem"]

    instanceId = configuration_item['configuration']['instanceId']

    ec2InstanceDetails = ec2_client.describe_instances(
        InstanceIds=[instanceId])['Reservations'][0]['Instances'][0]

    monitoringState = ec2InstanceDetails['Monitoring']['State']

    config_client = boto3.client("config")

    response = config_client.put_evaluations(
        Evaluations=[
            {
                'ComplianceResourceType': 'AWS::EC2::Instance',
                'ComplianceResourceId': instanceId,
                'ComplianceType': 'COMPLIANT' if monitoringState == 'enabled' else 'NON_COMPLIANT',
                'Annotation': 'Monitoring is not enabled',
                'OrderingTimestamp': config['notificationCreationTime']
            },
        ],
        ResultToken=event['resultToken']
    )

    return response
