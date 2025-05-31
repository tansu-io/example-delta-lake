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

```sh
git clone git@github.com:tansu-io/example-delta-duckdb.git
cd example-pyiceberg
```

Start everything up with:

```sh
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

```sh
just employee-topic-create
```

The above command will create an `tansu.employee` [Delta Lake](https://delta.io) table, that is [normalized](https://docs.rs/arrow/latest/arrow/array/struct.RecordBatch.html#method.normalize)
and partitioned on the `meta.year`, `meta.month`, `meta.day` from the Kafka message:

| config               | value                         |
|----------------------|-------------------------------|
| tansu.lake.partition | meta.year,meta.month,meta.day |
| tansu.lake.normalize | true                          |


Publish the sample data onto the employee topic:

```sh
just employee-produce
```

We can view the [Delta Lake](https://delta.io) table created in `s3://lake/tansu.employee` with:

```sh
just minio-mc ls -r local/lake/tansu.employee
```

Note that the `tansu.employee` table, is partitioned on the `meta.year`, `meta.month`, `meta.day`:

```sh
docker compose exec minio mc ls -r local/lake/tansu.employee
[2025-05-30 06:56:41 UTC] 2.5KiB STANDARD _delta_log/00000000000000000000.json
[2025-05-30 06:56:41 UTC]   998B STANDARD _delta_log/00000000000000000001.json
[2025-05-30 06:56:41 UTC] 1.8KiB STANDARD meta.year=2025/meta.month=5/meta.day=30/part-00000-47182dcc-6071-4836-8233-1ae50678194e-c000.parquet
```

To view the [Delta Lake](https://delta.io) table in DuckDB:

```sh
just employee-duckdb-delta
```

Giving the following output:

| meta.partition |     meta.timestamp      | meta.year | meta.month | meta.day | key.id | value.name |    value.email    |
|---------------:|-------------------------|----------:|-----------:|---------:|-------:|------------|-------------------|
| 0              | 2025-05-30 06:56:41.136 | 2025      | 5          | 30       | 12321  | Bob        | bob@example.com   |
| 0              | 2025-05-30 06:56:41.136 | 2025      | 5          | 30       | 32123  | Alice      | alice@example.com |

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

```sh
just grade-topic-create
```

The above command will create an `tansu.grade` [Delta Lake](https://delta.io) table, that is [normalized](https://docs.rs/arrow/latest/arrow/array/struct.RecordBatch.html#method.normalize),
partitioned on `meta.year` from the Kafka message, the [Z Order](https://delta.io/blog/2023-06-03-delta-lake-z-order/) of the data is `value.grade` :

| config                         | value                                                                     |
|--------------------------------|---------------------------------------------------------------------------|
| tansu.lake.partition           | meta_year                                                                 |
| tansu.lake.normalize           | true                                                                      |
| tansu.lake.normalize.separator | `_`                                                                       |
| tansu.lake.z_order             | `value_grade`                                                             |

Tansu will automatically maintain this table compacting small files and applying Z Ordering every 10 minutes or so.

Publish the sample data onto the grade topic:

```sh
just grade-produce
```

We can view the files created by Tansu in `s3://lake/tansu.grade` with:

```sh
just minio-mc ls -r local/lake/tansu.grade
```

Note that the `tansu.grade` table, is partitioned on the `meta.year`:

```sh
[2025-05-31 06:57:19 UTC] 3.4KiB STANDARD _delta_log/00000000000000000000.json
[2025-05-31 06:57:19 UTC] 1.4KiB STANDARD _delta_log/00000000000000000001.json
[2025-05-31 06:57:19 UTC] 5.4KiB STANDARD meta.year=2025/part-00000-bd6bce1a-0288-4ab2-9a40-01dc0bff2199-c000.parquet
```

View the data in DuckDB:

```sh
just grade-duckdb-delta
```

Giving the following output, note that the `grade` is unordered:

| meta_day | meta_month | meta_partition |        meta_timestamp         | meta_year |     key     | value_final | value_first | value_grade | value_last | value_test1 | value_test2 | value_test3 | value_test4 |
|---------:|-----------:|---------------:|-------------------------------|----------:|-------------|------------:|-------------|-------------|------------|------------:|------------:|------------:|------------:|
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 345-67-8901 | 43.0        | Cecil       | F           | Noshow     | 45.0        | 11.0        | -1.0        | 4.0         |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 123-12-1234 | 48.0        | University  | D+          | Alfred     | 41.0        | 97.0        | 96.0        | 97.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 123-45-6789 | 49.0        | Aloysius    | D-          | Alfalfa    | 40.0        | 90.0        | 100.0       | 83.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 234-56-7890 | 46.0        | Betty       | C-          | Rubble     | 44.0        | 90.0        | 80.0        | 90.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 567-89-0123 | 44.0        | Gramma      | C           | Gerty      | 41.0        | 80.0        | 60.0        | 40.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 632-79-9939 | 50.0        | Bif         | B+          | Buff       | 46.0        | 20.0        | 30.0        | 40.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 456-78-9012 | 45.0        | Fred        | A-          | Bumpkin    | 43.0        | 78.0        | 88.0        | 77.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 087-65-4321 | 47.0        | Electric    | B-          | Android    | 42.0        | 23.0        | 36.0        | 45.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 345-67-3901 | 4.0         | Boy         | B           | George     | 40.0        | 1.0         | 11.0        | -1.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 143-12-1234 | 97.0        | Jim         | A+          | Backus     | 48.0        | 1.0         | 97.0        | 96.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 565-89-0123 | 40.0        | Art         | D+          | Carnivore  | 44.0        | 1.0         | 80.0        | 60.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 632-79-9439 | 40.0        | Harvey      | C           | Heffalump  | 30.0        | 1.0         | 20.0        | 30.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 234-56-2890 | 90.0        | Benny       | B-          | Franklin   | 50.0        | 1.0         | 90.0        | 80.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 223-45-6789 | 83.0        | Andrew      | A           | Airpump    | 49.0        | 1.0         | 90.0        | 100.0       |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 087-75-4321 | 45.0        | Jim         | C+          | Dandy      | 47.0        | 1.0         | 23.0        | 36.0        |
| 31       | 5          | 0              | 2025-05-31T08:05:37.956+00:00 | 2025      | 456-71-9012 | 77.0        | Ima         | B-          | Elephant   | 45.0        | 1.0         | 78.0        | 88.0        |

After maintenance has run the table is ordered by `grade`:

| meta_day | meta_month | meta_partition |        meta_timestamp         | meta_year |     key     | value_final | value_first | value_grade | value_last | value_test1 | value_test2 | value_test3 | value_test4 |
|---------:|-----------:|---------------:|-------------------------------|----------:|-------------|------------:|-------------|-------------|------------|------------:|------------:|------------:|------------:|
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 223-45-6789 | 83.0        | Andrew      | A           | Airpump    | 49.0        | 1.0         | 90.0        | 100.0       |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 143-12-1234 | 97.0        | Jim         | A+          | Backus     | 48.0        | 1.0         | 97.0        | 96.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 456-78-9012 | 45.0        | Fred        | A-          | Bumpkin    | 43.0        | 78.0        | 88.0        | 77.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 345-67-3901 | 4.0         | Boy         | B           | George     | 40.0        | 1.0         | 11.0        | -1.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 632-79-9939 | 50.0        | Bif         | B+          | Buff       | 46.0        | 20.0        | 30.0        | 40.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 087-65-4321 | 47.0        | Electric    | B-          | Android    | 42.0        | 23.0        | 36.0        | 45.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 456-71-9012 | 77.0        | Ima         | B-          | Elephant   | 45.0        | 1.0         | 78.0        | 88.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 234-56-2890 | 90.0        | Benny       | B-          | Franklin   | 50.0        | 1.0         | 90.0        | 80.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 567-89-0123 | 44.0        | Gramma      | C           | Gerty      | 41.0        | 80.0        | 60.0        | 40.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 632-79-9439 | 40.0        | Harvey      | C           | Heffalump  | 30.0        | 1.0         | 20.0        | 30.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 087-75-4321 | 45.0        | Jim         | C+          | Dandy      | 47.0        | 1.0         | 23.0        | 36.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 234-56-7890 | 46.0        | Betty       | C-          | Rubble     | 44.0        | 90.0        | 80.0        | 90.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 123-12-1234 | 48.0        | University  | D+          | Alfred     | 41.0        | 97.0        | 96.0        | 97.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 565-89-0123 | 40.0        | Art         | D+          | Carnivore  | 44.0        | 1.0         | 80.0        | 60.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 123-45-6789 | 49.0        | Aloysius    | D-          | Alfalfa    | 40.0        | 90.0        | 100.0       | 83.0        |
| 31       | 5          | 0              | 2025-05-31T08:31:39.065+00:00 | 2025      | 345-67-8901 | 43.0        | Cecil       | F           | Noshow     | 45.0        | 11.0        | -1.0        | 4.0         |

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

```sh
just observation-topic-create
```

Publish the sample data onto the observation topic:

```sh
just observation-produce
```

View the data in DuckDB:

```sh
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

```sh
just person-topic-create
```

Publish the sample data onto the person topic:

```sh
just person-produce
```

View the data in DuckDB:

```sh
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

```sh
just search-topic-create
```

Publish the sample data onto the search topic:

```sh
just search-produce
```

View the data in DuckDB:

```sh
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

```sh
just taxi-topic-create
```

Publish the sample data onto the taxi topic:

```sh
just taxi-produce
```

View the data in DuckDB:

```sh
just taxi-duckdb-delta
```

Giving the following output:

|                          meta                          |                                                value                                                 |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 1, 'trip_id': 1000371, 'trip_distance': 1.8, 'fare_amount': 15.32, 'store_and_fwd': 0} |
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 2, 'trip_id': 1000372, 'trip_distance': 2.5, 'fare_amount': 22.15, 'store_and_fwd': 0} |
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 2, 'trip_id': 1000373, 'trip_distance': 0.9, 'fare_amount': 9.01, 'store_and_fwd': 0}  |
| {'partition': 0, 'timestamp': 2025-05-25 14:58:11.719} | {'vendor_id': 1, 'trip_id': 1000374, 'trip_distance': 8.4, 'fare_amount': 42.13, 'store_and_fwd': 1} |
