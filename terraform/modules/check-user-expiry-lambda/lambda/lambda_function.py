import os
import datetime
from dateutil.relativedelta import relativedelta
import boto3
from boto3.dynamodb.conditions import Key, Attr

mail_from = os.environ.get("MAIL_FROM")
if mail_from is None:
    message = "Variable MAIL_FROM was not provided."
    print(message)
    raise Exception(message)

subject_line = os.environ.get("SUBJECT_LINE")
if subject_line is None:
    message = "Variable SUBJECT_LINE was not provided."
    print(message)
    raise Exception(message)

region_name = os.environ.get("AWS_REGION")
if region_name is None:
    message = "Variable AWS_REGION was not provided."
    print(message)
    raise Exception(message)

table_name = os.environ.get("TABLE_NAME")
if table_name is None:
    message = "Variable TABLE_NAME was not provided."
    print(message)
    raise Exception(message)

bucket_name = os.environ.get("BUCKET_NAME")
if bucket_name is None:
    message = "Variable BUCKET_NAME was not provided."
    print(message)
    raise Exception(message)

cognito_user_pool_id = os.environ.get("COGNITO_USER_POOL_ID")
if cognito_user_pool_id is None:
    message = "Variable COGNITO_USER_POOL_ID was not provided."
    print(message)
    raise Exception(message)

dynamodb = boto3.resource("dynamodb", region_name=region_name)
table = dynamodb.Table(table_name)
s3 = boto3.client("s3")
ses = boto3.client("ses", region_name=region_name)
cognito = boto3.client("cognito-idp", region_name=region_name)


def read_object_from_bucket(object_name):
    print("Getting object " + object_name + " from bucket " + bucket_name)
    data = s3.get_object(Bucket=bucket_name, Key=object_name)
    contents = data["Body"].read().decode(encoding="utf-8", errors="ignore").strip()
    return contents


def query_dynamodb_users_about_expire():
    print("Query dynamodb table user for users about to expire")
    today = datetime.date.today()
    today_plus_two_weeks = today + relativedelta(weeks=2)
    response = table.scan(
        FilterExpression=Attr("expiration_date").between(
            str(today), str(today_plus_two_weeks)
        )
    )
    return response["Items"]


def process_items(items):
    print("Process items")
    email_from = mail_from
    email_subject = subject_line
    email_body = read_object_from_bucket("default_email_template_analytical.html")
    print("email_from=" + email_from)
    print("email_subject=" + email_subject)
    print("email_body=" + email_body)

    for item in items:
        print(item["username"][:-3] + " " + item["expiration_date"])
        formatted_time = datetime.datetime.strptime(item["expiration_date"], "%Y-%m-%dT%H:%M:%S.%fZ")
        days = (
            formatted_time.date() - datetime.date.today()
        )
        subject_with_username = email_subject.replace("[[ recipient_name ]]", item["username"][:-3])
        email_body_with_values = email_body.replace(
            "[[ recipient_name ]]", item["username"][:-3]
        ).replace("[[ number_of_days_until_expiry ]]", str(days.days).replace("[[ title ]]", email_subject))
        email_to = query_user_email_from_cognito(item["username"][:-3])
        print("Sending email to: " + email_to)
        send_email(email_from, email_to, subject_with_username, email_body_with_values)


def query_user_email_from_cognito(username):
    response = cognito.admin_get_user(
        UserPoolId=cognito_user_pool_id, Username=username
    )
    return extract_email_from_user_attributes(response)


def extract_email_from_user_attributes(user):
    for attribute in user["UserAttributes"]:
        if attribute["Name"] == "email":
            return attribute["Value"]
    message = "Email attribute not found for user: " + user["Username"]
    print(message)
    raise Exception(message)


def send_email(email_from, email_to, email_subject, email_body):
    CHARSET = "UTF-8"
    ses.send_email(
        Destination={"ToAddresses": [email_to,],},
        Message={
            "Body": {"Html": {"Charset": CHARSET, "Data": email_body,},},
            "Subject": {"Charset": CHARSET, "Data": email_subject,},
        },
        Source=email_from,
    )


def lambda_handler(event, context):
    items = query_dynamodb_users_about_expire()
    if items:
        print("Query returned " + str(len(items)) + " item(s)")
        process_items(items)
    else:
        print("Query did not return any items.")