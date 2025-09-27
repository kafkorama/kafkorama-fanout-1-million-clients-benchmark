# Benchmarking Kafkorama: One Million Messages Per Second to One Million Concurrent Users (Scale-Up and Scale-Out)

## Abstract

Apache Kafka® powers massive volumes of real-time data, but building apps on top of it usually requires specialized Kafka developers who rely on Kafka client SDKs to build backend apps.

**Kafkorama** removes this barrier by exposing the same real-time data as Streaming APIs — enabling any developer to go beyond backend apps and build real-time web, mobile, and IoT apps.

You can think of Kafkorama as a streaming-based API management solution for Apache Kafka, analogous to traditional REST-based API management with its usual components of an API Portal and a Gateway. But, above all, it extends Kafka to real-time web, mobile, or IoT apps at scale.

In this post, we share benchmark results showing how Kafkorama Gateway scales both vertically and horizontally — delivering **one million messages per second** to **one million concurrent clients** over WebSockets, with end-to-end mean latency under **5 milliseconds**.
