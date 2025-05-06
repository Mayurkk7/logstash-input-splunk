# Logstash input plugin for Splunk

## Description

The logstash-input-splunk plugin is a custom Logstash input plugin that enables direct ingestion of data from Splunk into Logstash. It was developed to bridge the gap between Splunk and modern data pipelines, allowing users to unify their logging infrastructure and route data to various destinations for processing, storage, or analysis.

By leveraging Splunk's REST API, the plugin supports searching and exporting events based on time ranges or specific queries. It integrates seamlessly into Logstash pipelines and is fully configurable to support a range of use cases — from migrating data to the Elastic Stack (Elasticsearch, Kibana) to forwarding it to Kafka, writing to flat files, or any other supported Logstash output.

Designed with flexibility and performance in mind, the plugin makes it easy to incorporate Splunk data into broader observability or data engineering workflows.

## Input Configuration Options

<table>
  <tr>
    <th>Parameter</th>
    <th>Input type</th>
    <th>Required</th>
  </tr>
  <tr style="background-color: #ffffff;">
    <td>splunk_url</td>
    <td>string</td>
    <td>Yes</td>
  </tr>
  <tr style="background-color: #f2f2f2;">
    <td>username</td>
    <td>string</td>
    <td>Yes</td>
  </tr>
  <tr style="background-color: #ffffff;">
    <td>password</td>
    <td>string</td>
    <td>Yes</td>
  </tr>
  <tr style="background-color: #f2f2f2;">
    <td>index</td>
    <td>string</td>
    <td>Yes</td>
  </tr>
  <tr style="background-color: #ffffff;">
    <td>fetch_offset_limit</td>
    <td>number</td>
    <td>No</td>
  </tr>
  <tr style="background-color: #f2f2f2;">
    <td>max_fetch_size_in_mb</td>
    <td>number</td>
    <td>No</td>
  </tr>
</table>

## Description of input configuration options

`splunk_url` 

  * Value type is string
  * The base URL of your Splunk instance (e.g., https://localhost:8089). Used by the plugin to connect and fetch data via the       Splunk       REST API.

`username` 

  * Value type is string
  * The username used to authenticate with your Splunk instance.

`password` 

  * Value type is string
  * The corresponding password for the Splunk user.

`index` 

  * Value type is string
  * The name of the Splunk index from which events will be fetched.

`fetch_offset_limit` 

  * Value type is number
  * Default value is 50
  * The maximum number of events to retrieve per request from the Splunk API.

`max_fetch_size_in_mb` 

  * Value type is number
  * Default value is 10
  * The upper limit (in megabytes) of total event data to push into the Logstash queue in a single iteration.

## How to Set Up

### Follow these steps to build and install the plugin:

#### 1. Clone the Repository <br>
```
git clone https://github.com/Mayurkk7/logstash-input-splunk.git
cd logstash-input-splunk
```
#### 2. Build the Ruby Gem <br>
```
gem build logstash-input-splunk.gemspec
```
- This will generate a .gem file for the plugin.

#### 3. Install Logstash (if not already installed) <br>
- Download and install Logstash from the official website.

#### 4. Install the Plugin into Logstash <br>

- Navigate to the Logstash bin directory:
```
cd path-to-your-logstash-directory/logstash/bin
```
- Install the plugin:
```
./logstash-plugin install --no-verify /full/path/to/logstash-input-splunk-<version>.gem
```

#### 5. Verify Plugin Installation <br>
- Navigate to the Logstash bin directory.
- Run the command:
```
./logstash-plugin list
```
- Check that logstash-input-splunk appears in the list of installed plugins.

#### 6. Configure Logstash to Use the Plugin <br>
- Create or update your Logstash configuration file (.conf) with the following input block:
```
splunk {
        splunk_url => "https://localhost:8089"
        username => "your_username"
        password => "your_password"
        index => "your_index_name"
        fetch_offset_limit => 1
        max_fetch_size_in_mb => 10
 }
```
- Put this code block in the input section of .conf file
- Customize the parameters based on your Splunk setup.

#### 7. Run Logstash <br>
- Navigate to the Logstash bin directory.
- Start the Logstash service to begin ingesting data from Splunk:
```
./logstash -f path-to-your-config-file.conf
```

## Tracking State and Watermark Persistence

The plugin tracks the current position of data by persisting a watermark, which is included directly within the Splunk search query. This allows Logstash to efficiently resume processing from the exact point where it left off, ensuring no data is missed or redundantly processed after a restart or failure.

The plugin leverages _indextime and _cd (both created by default by Splunk during data ingestion) as part of a composite key. This key, consists of:

_indextime (the time when the event was indexed into Splunk),

bucket_id (extracted from _cd),

offset (extracted from _cd),

This ensures that only the new or unprocessed data since the last watermark position is retrieved, significantly reducing the risk of data duplication.

To persist the watermark, the plugin uses Marshal module and a custom high-performance binary serialization mechanism in Ruby. The state is written to a storage file (e.g. state.dat) located in Logstash’s 'home/data/plugins/inputs/file/' directory. The use of binary serialization optimizes read/write performance, enabling fast and efficient recovery.

In case of a crash, process failure or system restart, the plugin is designed to safely capture the operating system's signal and persist the current state of the watermark. This ensures no data is lost and processing resumes from the exact point it left off.

#### Key Features:

Efficient State Tracking: Watermark is embedded in the Splunk search query to track the data's position.

Fast Serialization: Uses Marshal module and Ruby object serialization for fast state persistence in binary format.

Crash Resilience: Captures operating system signals and persists the state during failure, ensuring no data redundancy.

Optimized Recovery: Ensures Logstash resumes from the exact position using the stored watermark without redundant data processing.
