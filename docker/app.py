import os
import time
import logging
import subprocess
from prometheus_client import start_http_server, Gauge, Info

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
log = logging.getLogger(__name__)

TYPE_VALUES = {'physical': 0,
                 'vm': 1,
             'container': 2}

CONTAINER_INDICATORS = ['docker', 'kube', 'lxc', 'containerd']
VM_INDICATORS = ['kvm', 'qemu', 'vmware', 'virtualbox', 'xen', 'hyper-v', 'amazon', 'google', 'bochs']


def detect_host_type():
    if os.path.exists('/.dockerenv'):
        return 'container'
    
    try:
        with open('/proc/1/cgroup') as f:
            if any(ind in f.read() for ind in CONTAINER_INDICATORS):
                return 'container'
    except:
        pass
    try:
        result = subprocess.run(['systemd-detect-virt'], capture_output=True, text=True, timeout=1)
        virt = result.stdout.strip()
        if virt == 'container':
            return 'container'
        if virt and virt != 'none':
            return 'vm'
    except:
        pass
    
    for path in ['/sys/class/dmi/id/product_name', '/sys/class/dmi/id/sys_vendor']:
        try:
            with open(path) as f:
                if any(ind in f.read().lower() for ind in VM_INDICATORS):
                    return 'vm'
        except:
            continue
    
    return 'physical'


def run_metrics_server(port=8080, interval=30):
    host_type_gauge = Gauge('host_type', 'Type of host', ['host_type'])
    host_info = Info('host', 'Host information')
    
    start_http_server(port)
    log.info(f"Server started on port {port}")
    
    while True:
        host_type = detect_host_type()
        host_type_gauge.labels(host_type=host_type).set(TYPE_VALUES[host_type])
        host_info.info({
            'type': host_type,
            'hostname': os.uname().nodename,
            'os': os.uname().sysname,
            'kernel': os.uname().release
        })
        
        log.info(f"Updated: {host_type}")
        time.sleep(interval)


if __name__ == "__main__":
    port = int(os.getenv('METRICS_PORT', 8080))
    interval = int(os.getenv('UPDATE_INTERVAL', 30))
    
    try:
        run_metrics_server(port, interval)
    except KeyboardInterrupt:
        log.info("Server stopped")
    except Exception as e:
        log.error(f"Error: {e}")
        raise