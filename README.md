## librato-kube-cadvisor

This provides a very simple bridge to send stats from the [cAdvisor](https://github.com/google/cadvisor) instances [integrated into a kube cluster](http://blog.kubernetes.io/2015/05/resource-usage-monitoring-kubernetes.html) to [Librato](https://librato.com).

Perhaps someday there will be a librato [sink in heapster](https://github.com/kubernetes/heapster/tree/78ff89c01f52c0ab49dac2d356a8371e79482544/sinks), but for now this is an easy way to forward high-level stats into librato.

### Required ENV vars

  * `LIBRATO_EMAIL`
  * `LIBRATO_API_KEY`
  * `CONTEXT` - this is prefixed to stats sent to librato
  * `KUBE_API_ENDPOINT`


### Deployment

Tweak the [sample replication controller](https://github.com/bkoski/librato-kube-cadvisor/blob/master/sample-rc.json), and submit it to your kubernetes cluster.
