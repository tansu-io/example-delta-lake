[Tansu](https://tansu.io) is an Apache Kafka API compatible broker written in async 🚀 Rust 🦀 with PostgreSQL, S3 or memory storage engines.

Topics [validated](https://github.com/tansu-io/tansu/blob/main/docs/schema-registry.md) by [JSON Schema](https://json-schema.org), [Apache Avro](https://avro.apache.org)
or [Protocol buffers](protocol-buffers) can be written as [Apache Iceberg](https://iceberg.apache.org) or [Delta Lake](https://delta.io) tables

This repository showcases examples of structured data published to schema-backed topics, instantly accessible as [Delta Lake](https://delta.io) tables.

Prerequisites:
- **[docker](https://www.docker.com)**, using [compose.yaml](compose.yaml) which runs [tansu](https://tansu.io) and [MinIO](https://min.io)
- **[duckdb](https://duckdb.org)**, a fast open source database system [that has native support for Delta Lake](https://duckdb.org/2024/06/10/delta.html)
- **[just](https://github.com/casey/just)**, a handy way to save and run project-specific commands

The [justfile](./justfile) contains recipes to create topics, produce and query data.

Once you have the prerequisites installed, clone this repository and start everything up with:

```shell
git clone git@github.com:tansu-io/example-delta-duckdb.git
cd example-pyiceberg
```

Start everything up with:

```shell
just up
```

Should result in:

```
✔ Network example-delta-duckdb_default    Created
✔ Volume "example-delta-duckdb_minio"     Created
✔ Container example-delta-duckdb-minio-1  Healthy
docker compose exec minio mc ready local
mc: Configuration written to `/tmp/.mc/config.json`. Please update your access credentials.
mc: Successfully created `/tmp/.mc/share`.
mc: Initialized share uploads `/tmp/.mc/share/uploads.json` file.
mc: Initialized share downloads `/tmp/.mc/share/downloads.json` file.
The cluster 'local' is ready
docker compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
Added `local` successfully.
docker compose exec minio mc mb local/tansu
Bucket created successfully `local/tansu`.
docker compose exec minio mc mb local/lake
Bucket created successfully `local/lake`.
docker compose up --detach --wait tansu
✔ tansu Pulled
✔ Container example-delta-duckdb-tansu-1  Healthy
```

The above does the following:
- starts the [MinIO](https://min.io) S3 compatible service
- creates a `s3://lake` bucket in [MinIO](https://min.io), used to store the [Delta Lake](https://delta.io) tables
- creates a `s3://tansu` bucket in [MinIO](https://min.io), used to store Kafka related data used by [tansu](https://tansu.io)
- runs the [tansu](https://tansu.io) broker configured to use [MinIO](https://min.io) as the storage engine with [Delta Lake](https://delta.io)



Done! You can now run the examples.

## Employee

Employee is a protocol buffer backed topic, with the following schema [employee.proto](schema/employee.proto):

```proto
syntax = 'proto3';

message Key {
  int32 id = 1;
}

message Value {
  string name = 1;
  string email = 2;
}
```

Sample employee data is in [employees.json](data/employees.json):

```json
[
  {
    "key": { "id": 12321 },
    "value": { "name": "Bob", "email": "bob@example.com" }
  },
  {
    "key": { "id": 32123 },
    "value": { "name": "Alice", "email": "alice@example.com" }
  }
]
```

Create the employee topic:

```bash
just employee-topic-create
```

Publish the sample data onto the employee topic:

```bash
just employee-produce
```

We can view the files created by Tansu in `s3://lake/tansu.employee` with:

```bash
just minio-mc ls -r local/lake/tansu.employee
```

```bash
[2025-05-25 11:30:03 UTC] 3.0KiB STANDARD _delta_log/00000000000000000000.json
[2025-05-25 11:30:03 UTC]   868B STANDARD _delta_log/00000000000000000001.json
[2025-05-25 11:30:03 UTC] 2.5KiB STANDARD part-00000-73eafe99-1203-4d4e-9d68-af24b3c02533-c000.parquet
```

To view the data in DuckDB:

```bash
just employee-duckdb-delta
```

Giving the following output:

|                          meta                          |      key      |                    value                    |
|--------------------------------------------------------|---------------|---------------------------------------------|
| {'partition': 0, 'timestamp': 2025-05-25 11:14:58.903} | {'id': 12321} | {'name': Bob, 'email': bob@example.com}     |
| {'partition': 0, 'timestamp': 2025-05-25 11:14:58.903} | {'id': 32123} | {'name': Alice, 'email': alice@example.com} |

## Grade

Grade is a JSON schema backed topic, with the following schema [grade.json](schema/grade.json):

```json
{
  "type": "record",
  "name": "Grade",

  "fields": [
    { "name": "key", "type": "string", "pattern": "^\\d{3}-\\d{2}-\\d{4}$" },
    {
      "name": "value",
      "type": {
        "type": "record",
        "fields": [
          { "name": "first", "type": "string" },
          { "name": "last", "type": "string" },
          { "name": "test1", "type": "double" },
          { "name": "test2", "type": "double" },
          { "name": "test3", "type": "double" },
          { "name": "test4", "type": "double" },
          { "name": "final", "type": "double" },
          { "name": "grade", "type": "string" }
        ]
      }
    }
  ]
}
```

Sample grade data is in: [grades.json](data/grades.json):

```json
[
  {
    "key": "123-45-6789",
    "value": {
      "lastName": "Alfalfa",
      "firstName": "Aloysius",
      "test1": 40.0,
      "test2": 90.0,
      "test3": 100.0,
      "test4": 83.0,
      "final": 49.0,
      "grade": "D-"
    }
  },
  ...
]
```

Create the grade topic:

```bash
just grade-topic-create
```

Publish the sample data onto the grade topic:

```bash
just grade-produce
```

We can view the files created by Tansu in `s3://lake/tansu.grade` with:

```bash
just minio-mc ls -r local/lake/tansu.grade
```

```bash
[2025-05-25 14:04:41 UTC] 3.2KiB STANDARD _delta_log/00000000000000000000.json
[2025-05-25 14:04:41 UTC]   924B STANDARD _delta_log/00000000000000000001.json
[2025-05-25 14:04:41 UTC] 4.7KiB STANDARD part-00000-0d6c55ef-7f2b-47e7-b3e2-98089d7fff45-c000.parquet
```

View the data in DuckDB:

```bash
just grade-duckdb-delta
```

Giving the following output:

|     key     |                                                             value                                                             |
|-------------|-------------------------------------------------------------------------------------------------------------------------------|
| 123-45-6789 | {'final': 49.0, 'first': Aloysius, 'grade': D-, 'last': Alfalfa, 'test1': 40.0, 'test2': 90.0, 'test3': 100.0, 'test4': 83.0} |
| 123-12-1234 | {'final': 48.0, 'first': University, 'grade': D+, 'last': Alfred, 'test1': 41.0, 'test2': 97.0, 'test3': 96.0, 'test4': 97.0} |
| 567-89-0123 | {'final': 44.0, 'first': Gramma, 'grade': C, 'last': Gerty, 'test1': 41.0, 'test2': 80.0, 'test3': 60.0, 'test4': 40.0}       |
| 087-65-4321 | {'final': 47.0, 'first': Electric, 'grade': B-, 'last': Android, 'test1': 42.0, 'test2': 23.0, 'test3': 36.0, 'test4': 45.0}  |
| 456-78-9012 | {'final': 45.0, 'first': Fred, 'grade': A-, 'last': Bumpkin, 'test1': 43.0, 'test2': 78.0, 'test3': 88.0, 'test4': 77.0}      |
| 234-56-7890 | {'final': 46.0, 'first': Betty, 'grade': C-, 'last': Rubble, 'test1': 44.0, 'test2': 90.0, 'test3': 80.0, 'test4': 90.0}      |
| 345-67-8901 | {'final': 43.0, 'first': Cecil, 'grade': F, 'last': Noshow, 'test1': 45.0, 'test2': 11.0, 'test3': -1.0, 'test4': 4.0}        |
| 632-79-9939 | {'final': 50.0, 'first': Bif, 'grade': B+, 'last': Buff, 'test1': 46.0, 'test2': 20.0, 'test3': 30.0, 'test4': 40.0}          |
| 223-45-6789 | {'final': 83.0, 'first': Andrew, 'grade': A, 'last': Airpump, 'test1': 49.0, 'test2': 1.0, 'test3': 90.0, 'test4': 100.0}     |
| 143-12-1234 | {'final': 97.0, 'first': Jim, 'grade': A+, 'last': Backus, 'test1': 48.0, 'test2': 1.0, 'test3': 97.0, 'test4': 96.0}         |
| 565-89-0123 | {'final': 40.0, 'first': Art, 'grade': D+, 'last': Carnivore, 'test1': 44.0, 'test2': 1.0, 'test3': 80.0, 'test4': 60.0}      |
| 087-75-4321 | {'final': 45.0, 'first': Jim, 'grade': C+, 'last': Dandy, 'test1': 47.0, 'test2': 1.0, 'test3': 23.0, 'test4': 36.0}          |
| 456-71-9012 | {'final': 77.0, 'first': Ima, 'grade': B-, 'last': Elephant, 'test1': 45.0, 'test2': 1.0, 'test3': 78.0, 'test4': 88.0}       |
| 234-56-2890 | {'final': 90.0, 'first': Benny, 'grade': B-, 'last': Franklin, 'test1': 50.0, 'test2': 1.0, 'test3': 90.0, 'test4': 80.0}     |
| 345-67-3901 | {'final': 4.0, 'first': Boy, 'grade': B, 'last': George, 'test1': 40.0, 'test2': 1.0, 'test3': 11.0, 'test4': -1.0}           |
| 632-79-9439 | {'final': 40.0, 'first': Harvey, 'grade': C, 'last': Heffalump, 'test1': 30.0, 'test2': 1.0, 'test3': 20.0, 'test4': 30.0}    |

## Observation

Observation is an Avro backed topic, with the following schema [observation.avsc](schema/observation.avsc):

```json
{
  "type": "record",
  "name": "observation",
  "fields": [
    { "name": "key", "type": "string", "logicalType": "uuid" },
    {
      "name": "value",
      "type": "record",
      "fields": [
        { "name": "amount", "type": "double" },
        { "name": "unit", "type": "enum", "symbols": ["CELSIUS", "MILLIBAR"] }
      ]
    }
  ]
}
```

Sample observation data, is in: [observations.json](data/observations.json):

```json
[
  {
    "key": "1E44D9C2-5E7A-443B-BF10-2B1E5FD72F15",
    "value": { "amount": 23.2, "unit": "CELSIUS" }
  },
  ...
]
```

Create the observation topic:

```bash
just observation-topic-create
```

Publish the sample data onto the observation topic:

```bash
just observation-produce
```

View the data in DuckDB:

```bash
just observation-duckdb-delta
```

Giving the following output:

|                 key                  |                value                 |                          meta                          |
|--------------------------------------|--------------------------------------|--------------------------------------------------------|
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 23.2, 'unit': CELSIUS}    | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 1027.0, 'unit': MILLIBAR} | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 22.8, 'unit': CELSIUS}    | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 1023.0, 'unit': MILLIBAR} | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 22.5, 'unit': CELSIUS}    | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 1018.0, 'unit': MILLIBAR} | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 23.1, 'unit': CELSIUS}    | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 1020.0, 'unit': MILLIBAR} | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 23.4, 'unit': CELSIUS}    | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |
| 1e44d9c2-5e7a-443b-bf10-2b1e5fd72f15 | {'amount': 1025.0, 'unit': MILLIBAR} | {'partition': 0, 'timestamp': 2025-05-25 14:08:24.539} |

## Person

Person is a JSON schema backed topic, with the following schema [person.json](schema/person.json):

```json
{
  "title": "Person",
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "pattern": "^\\d{3}-\\d{2}-\\d{4}$"
    },
    "value": {
      "type": "object",
      "properties": {
        "firstName": {
          "type": "string",
          "description": "The person's first name."
        },
        "lastName": {
          "type": "string",
          "description": "The person's last name."
        },
        "age": {
          "description": "Age in years which must be equal to or greater than zero.",
          "type": "integer",
          "minimum": 0
        }
      }
    }
  }
}
```

Sample person data, is in [persons.json](data/persons.json):

```json
[
  {
    "key": "123-45-6789",
    "value": { "lastName": "Alfalfa", "firstName": "Aloysius", "age": 21 }
  },
  ...
]
```

Create the person topic:

```bash
just person-topic-create
```

Publish the sample data onto the person topic:

```bash
just person-produce
```

View the data in DuckDB:

```bash
just person-duckdb-delta
```

Giving the following output:

|     key     |                          value                           |
|-------------|----------------------------------------------------------|
| 123-45-6789 | {'age': 21, 'firstName': Aloysius, 'lastName': Alfalfa}  |
| 123-12-1234 | {'age': 52, 'firstName': University, 'lastName': Alfred} |
| 567-89-0123 | {'age': 35, 'firstName': Gamma, 'lastName': Gerty}       |
| 087-65-4321 | {'age': 23, 'firstName': Electric, 'lastName': Android}  |
| 456-78-9012 | {'age': 72, 'firstName': Fred, 'lastName': Bumpkin}      |
| 234-56-7890 | {'age': 44, 'firstName': Betty, 'lastName': Rubble}      |
| 345-67-8901 | {'age': 67, 'firstName': Cecil, 'lastName': Noshow}      |
| 632-79-9939 | {'age': 38, 'firstName': Buff, 'lastName': Bif}          |
| 223-45-6789 | {'age': 42, 'firstName': Andrew, 'lastName': Airpump}    |
| 143-12-1234 | {'age': 63, 'firstName': Jim, 'lastName': Backus}        |
| 565-89-0123 | {'age': 29, 'firstName': Art, 'lastName': Carnivore}     |
| 087-75-4321 | {'age': 56, 'firstName': Jim, 'lastName': Dandy}         |
| 456-71-9012 | {'age': 45, 'firstName': Ima, 'lastName': Elephant}      |
| 234-56-2890 | {'age': 54, 'firstName': Benny, 'lastName': Franklin}    |
| 345-67-3901 | {'age': 91, 'firstName': Boy, 'lastName': George}        |
| 632-79-9439 | {'age': 17, 'firstName': Harvey, 'lastName': Heffalump}  |

## Search

Search is a protocol buffer backedd topic, with the following schema [search.proto](schema/search.proto):

```proto
syntax = 'proto3';

enum Corpus {
  CORPUS_UNSPECIFIED = 0;
  CORPUS_UNIVERSAL = 1;
  CORPUS_WEB = 2;
  CORPUS_IMAGES = 3;
  CORPUS_LOCAL = 4;
  CORPUS_NEWS = 5;
  CORPUS_PRODUCTS = 6;
  CORPUS_VIDEO = 7;
}

message Value {
  string query = 1;
  int32 page_number = 2;
  int32 results_per_page = 3;
  Corpus corpus = 4;
}
```

Sample search data, is in [searches.json](data/searches.json):

```json
[
  {
    "value": {
      "query": "abc/def",
      "page_number": 6,
      "results_per_page": 13,
      "corpus": "CORPUS_WEB"
    }
  }
]
```

Create the search topic:

```bash
just search-topic-create
```

Publish the sample data onto the search topic:

```bash
just search-produce
```

View the data in DuckDB:

```bash
just search-duckdb-delta
```

Giving the following output:

|                          meta                          |                                   value                                   |
|--------------------------------------------------------|---------------------------------------------------------------------------|
| {'partition': 0, 'timestamp': 2025-05-25 15:06:18.507} | {'query': abc/def, 'page_number': 6, 'results_per_page': 13, 'corpus': 2} |

## Taxi

Taxi is a protocol buffer backed topic, with the following schema [taxi.proto](schema/taxi.proto):

```proto
syntax = 'proto3';

enum Flag {
    N = 0;
    Y = 1;
}

message Value {
  int64 vendor_id = 1;
  int64 trip_id = 2;
  float trip_distance = 3;
  double fare_amount = 4;
  Flag store_and_fwd = 5;
}
```

Sample trip data, is in [trips.json](data/trips.json):

```json
[
  {
    "value": {
      "vendor_id": 1,
      "trip_id": 1000371,
      "trip_distance": 1.8,
      "fare_amount": 15.32,
      "store_and_fwd": "N"
    }
  },
  ...
]
```

Create the taxi topic:

```bash
just taxi-topic-create
```

Publish the sample data onto the taxi topic:

```bash
just taxi-produce
```

View the data in DuckDB:

```bash
just taxi-duckdb-delta
```

Giving the following output:

|                          meta                          |                                                value                                                 |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 1, 'trip_id': 1000371, 'trip_distance': 1.8, 'fare_amount': 15.32, 'store_and_fwd': 0} |
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 2, 'trip_id': 1000372, 'trip_distance': 2.5, 'fare_amount': 22.15, 'store_and_fwd': 0} |
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 2, 'trip_id': 1000373, 'trip_distance': 0.9, 'fare_amount': 9.01, 'store_and_fwd': 0}  |
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 1, 'trip_id': 1000374, 'trip_distance': 8.4, 'fare_amount': 42.13, 'store_and_fwd': 1} |

