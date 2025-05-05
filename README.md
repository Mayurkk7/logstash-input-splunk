# Logstash Plugin

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
