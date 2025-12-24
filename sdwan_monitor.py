#!/usr/bin/env python3
"""
SD-WAN Network Monitoring and Health Check System
Monitors latency, packet loss, bandwidth, and triggers anomaly detection
"""

import subprocess
import json
import time
import sys
from datetime import datetime
from collections import defaultdict, deque
import statistics

class NetworkMonitor:
    def __init__(self):
        self.metrics_history = defaultdict(lambda: {
            'latency': deque(maxlen=100),
            'loss': deque(maxlen=100),
            'bandwidth': deque(maxlen=100)
        })
        self.anomaly_threshold = 2.5  # Standard deviations
        self.alert_count = 0
        
    def ping_test(self, source_ns, target_ip, count=10):
        """Perform ping test from namespace to target"""
        try:
            cmd = [
                'ip', 'netns', 'exec', source_ns,
                'ping', '-c', str(count), '-i', '0.2', '-W', '1', target_ip
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            
            if result.returncode == 0:
                # Parse ping output
                output = result.stdout
                
                # Extract packet loss
                loss_line = [l for l in output.split('\n') if 'packet loss' in l]
                if loss_line:
                    loss = float(loss_line[0].split('%')[0].split()[-1])
                else:
                    loss = 0
                
                # Extract latency statistics
                stats_line = [l for l in output.split('\n') if 'rtt min/avg/max' in l or 'min/avg/max' in l]
                if stats_line:
                    stats = stats_line[0].split('=')[-1].strip().split('/')
                    latency_min = float(stats[0])
                    latency_avg = float(stats[1])
                    latency_max = float(stats[2].split()[0])
                    
                    return {
                        'success': True,
                        'latency_ms': latency_avg,
                        'latency_min': latency_min,
                        'latency_max': latency_max,
                        'packet_loss_percent': loss,
                        'packets_sent': count,
                        'packets_received': count - int(count * loss / 100)
                    }
            
            return {'success': False, 'error': 'Ping failed'}
            
        except subprocess.TimeoutExpired:
            return {'success': False, 'error': 'Timeout'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def bandwidth_test(self, server_ns, client_ns, server_ip, duration=5):
        """Perform bandwidth test using iperf3"""
        try:
            # Start iperf3 server
            server_proc = subprocess.Popen(
                ['ip', 'netns', 'exec', server_ns, 'iperf3', '-s', '-1'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait for server to start
            time.sleep(1)
            
            # Run iperf3 client
            cmd = [
                'ip', 'netns', 'exec', client_ns,
                'iperf3', '-c', server_ip, '-t', str(duration), '-J'
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration+5)
            
            # Kill server
            server_proc.terminate()
            server_proc.wait(timeout=2)
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                bandwidth_bps = data['end']['sum_sent']['bits_per_second']
                bandwidth_mbps = bandwidth_bps / 1_000_000
                
                return {
                    'success': True,
                    'bandwidth_mbps': bandwidth_mbps,
                    'bytes_sent': data['end']['sum_sent']['bytes'],
                    'retransmits': data['end']['sum_sent'].get('retransmits', 0)
                }
            
            return {'success': False, 'error': 'Bandwidth test failed'}
            
        except subprocess.TimeoutExpired:
            if server_proc:
                server_proc.kill()
            return {'success': False, 'error': 'Timeout'}
        except Exception as e:
            if server_proc:
                server_proc.kill()
            return {'success': False, 'error': str(e)}
    
    def check_link_health(self, source_ns, target_ip, link_id):
        """Comprehensive link health check"""
        print(f"\n{'='*60}")
        print(f"Link Health Check: {source_ns} -> {target_ip}")
        print(f"Link ID: {link_id} | Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*60}")
        
        # Ping test
        print("Running ping test...", end=' ')
        ping_result = self.ping_test(source_ns, target_ip, count=20)
        
        if ping_result['success']:
            latency = ping_result['latency_ms']
            loss = ping_result['packet_loss_percent']
            
            print(f"✓")
            print(f"  Latency: {latency:.2f} ms (min: {ping_result['latency_min']:.2f}, max: {ping_result['latency_max']:.2f})")
            print(f"  Packet Loss: {loss:.1f}%")
            
            # Store metrics
            self.metrics_history[link_id]['latency'].append(latency)
            self.metrics_history[link_id]['loss'].append(loss)
            
            # Anomaly detection
            self._detect_anomalies(link_id, latency, loss)
            
            # Health score
            health_score = self._calculate_health_score(latency, loss)
            print(f"  Health Score: {health_score}/100 {self._get_health_emoji(health_score)}")
            
        else:
            print(f"✗ ({ping_result.get('error', 'Unknown error')})")
            self.alert_count += 1
        
        print()
    
    def _calculate_health_score(self, latency, loss):
        """Calculate link health score (0-100)"""
        # Latency component (50% weight)
        latency_score = max(0, 100 - (latency / 2))
        
        # Loss component (50% weight)
        loss_score = max(0, 100 - (loss * 10))
        
        return (latency_score * 0.5 + loss_score * 0.5)
    
    def _get_health_emoji(self, score):
        """Get emoji based on health score"""
        if score >= 90:
            return "🟢 Excellent"
        elif score >= 70:
            return "🟡 Good"
        elif score >= 50:
            return "🟠 Fair"
        else:
            return "🔴 Poor"
    
    def _detect_anomalies(self, link_id, current_latency, current_loss):
        """Detect anomalies using statistical analysis"""
        history = self.metrics_history[link_id]
        
        if len(history['latency']) < 10:
            return  # Need more data points
        
        # Calculate statistics
        latency_mean = statistics.mean(history['latency'])
        latency_stdev = statistics.stdev(history['latency'])
        
        loss_mean = statistics.mean(history['loss'])
        
        # Check for latency anomaly
        if latency_stdev > 0:
            latency_zscore = (current_latency - latency_mean) / latency_stdev
            if abs(latency_zscore) > self.anomaly_threshold:
                print(f"  ⚠️  ANOMALY DETECTED: Latency spike ({current_latency:.2f}ms vs avg {latency_mean:.2f}ms)")
                self.alert_count += 1
        
        # Check for loss anomaly
        if current_loss > loss_mean + 5:
            print(f"  ⚠️  ANOMALY DETECTED: High packet loss ({current_loss:.1f}% vs avg {loss_mean:.1f}%)")
            self.alert_count += 1
    
    def display_metrics_summary(self):
        """Display summary of all collected metrics"""
        print(f"\n{'='*60}")
        print("METRICS SUMMARY")
        print(f"{'='*60}")
        
        for link_id, metrics in self.metrics_history.items():
            if len(metrics['latency']) > 0:
                print(f"\nLink: {link_id}")
                print(f"  Latency: avg={statistics.mean(metrics['latency']):.2f}ms, "
                      f"min={min(metrics['latency']):.2f}ms, "
                      f"max={max(metrics['latency']):.2f}ms")
                
                if len(metrics['latency']) > 1:
                    print(f"  Latency StdDev: {statistics.stdev(metrics['latency']):.2f}ms")
                
                print(f"  Packet Loss: avg={statistics.mean(metrics['loss']):.2f}%, "
                      f"max={max(metrics['loss']):.2f}%")
        
        print(f"\nTotal Anomalies Detected: {self.alert_count}")
        print(f"{'='*60}\n")
    
    def continuous_monitoring(self, interval=15):
        """Run continuous monitoring loop"""
        print("Starting continuous network monitoring...")
        print(f"Interval: {interval} seconds")
        print("Press Ctrl+C to stop\n")
        
        # Define test pairs (namespace, target_ip, link_id)
        test_pairs = [
            ('s1h1', '10.2.0.11', 'site1->site2'),
            ('s1h1', '10.3.0.11', 'site1->site3'),
            ('s2h1', '10.3.0.11', 'site2->site3'),
        ]
        
        iteration = 0
        try:
            while True:
                iteration += 1
                print(f"\n{'#'*60}")
                print(f"Monitoring Iteration #{iteration} - {datetime.now().strftime('%H:%M:%S')}")
                print(f"{'#'*60}")
                
                for source_ns, target_ip, link_id in test_pairs:
                    self.check_link_health(source_ns, target_ip, link_id)
                    time.sleep(2)
                
                # Display summary every 5 iterations
                if iteration % 5 == 0:
                    self.display_metrics_summary()
                
                print(f"\nWaiting {interval} seconds until next check...")
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n\nMonitoring stopped by user")
            self.display_metrics_summary()
    
    def run_comprehensive_test(self):
        """Run comprehensive one-time test"""
        print("\n" + "="*70)
        print("SD-WAN COMPREHENSIVE NETWORK TEST")
        print("="*70)
        
        test_scenarios = [
            {
                'name': 'Site 1 to Site 2 Connectivity',
                'source': 's1h1',
                'target': '10.2.0.11',
                'link_id': 'site1->site2'
            },
            {
                'name': 'Site 1 to Site 3 Connectivity',
                'source': 's1h1',
                'target': '10.3.0.11',
                'link_id': 'site1->site3'
            },
            {
                'name': 'Site 2 to Site 3 Connectivity',
                'source': 's2h1',
                'target': '10.3.0.11',
                'link_id': 'site2->site3'
            },
            {
                'name': 'Site 2 to Site 1 (Reverse)',
                'source': 's2h1',
                'target': '10.1.0.11',
                'link_id': 'site2->site1'
            }
        ]
        
        results = []
        for scenario in test_scenarios:
            self.check_link_health(
                scenario['source'],
                scenario['target'],
                scenario['link_id']
            )
            time.sleep(1)
        
        self.display_metrics_summary()
        
        print("\n" + "="*70)
        print("TEST COMPLETE")
        print("="*70)
        
        if self.alert_count == 0:
            print("✅ All tests passed successfully!")
        else:
            print(f"⚠️  {self.alert_count} anomalies detected")


def main():
    monitor = NetworkMonitor()
    
    if len(sys.argv) > 1 and sys.argv[1] == '--continuous':
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 15
        monitor.continuous_monitoring(interval)
    else:
        monitor.run_comprehensive_test()


if __name__ == '__main__':
    main()
