.output /dev/null

CREATE SECRET lake_house (
    TYPE s3,
    KEY_ID 'minioadmin',
    SECRET 'minioadmin',
    REGION 'eu-west-2',
    URL_STYLE 'path',
    USE_SSL false,
    ENDPOINT 'localhost:9000'
);

.output /dev/stdout
