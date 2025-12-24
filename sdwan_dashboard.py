#!/usr/bin/env python3
"""
SD-WAN Real-time Dashboard
Visual monitoring of network status, flows, and performance
"""

import subprocess
import sys
import time
import curses
from datetime import datetime
from collections import defaultdict

class SDWANDashboard:
    def __init__(self):
        self.refresh_interval = 2
        
    def get_ovs_status(self):
        """Get OVS bridge and port status"""
        try:
            result = subprocess.run(['ovs-vsctl', 'show'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                bridges = []
                current_bridge = None
                
                for line in lines:
                    if 'Bridge' in line and 'Bridge br-' in line:
                        current_bridge = line.split('"')[1] if '"' in line else None
                        if current_bridge:
                            bridges.append(current_bridge)
                
                return {'connected': True, 'bridges': bridges}
        except:
            pass
        return {'connected': False, 'bridges': []}
    
    def get_controller_status(self):
        """Check if Ryu controller is running"""
        try:
            result = subprocess.run(['pgrep', '-f', 'ryu-manager'], 
                                  capture_output=True, text=True)
            if result.returncode == 0 and result.stdout.strip():
                pid = result.stdout.strip().split()[0]
                return {'running': True, 'pid': pid}
        except:
            pass
        return {'running': False, 'pid': None}
    
    def get_flow_stats(self, bridge):
        """Get flow statistics from bridge"""
        try:
            result = subprocess.run(['ovs-ofctl', 'dump-flows', bridge, '-O', 'OpenFlow13'],
                                  capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                flow_count = sum(1 for line in lines if 'priority' in line)
                return flow_count
        except:
            pass
        return 0
    
    def ping_test_quick(self, source_ns, target_ip):
        """Quick ping test"""
        try:
            result = subprocess.run(
                ['ip', 'netns', 'exec', source_ns, 'ping', '-c', '3', '-W', '1', target_ip],
                capture_output=True, text=True, timeout=5
            )
            
            if result.returncode == 0:
                output = result.stdout
                loss_line = [l for l in output.split('\n') if 'packet loss' in l]
                if loss_line:
                    loss = float(loss_line[0].split('%')[0].split()[-1])
                    
                    stats_line = [l for l in output.split('\n') if 'min/avg/max' in l]
                    if stats_line:
                        stats = stats_line[0].split('=')[-1].strip().split('/')
                        latency = float(stats[1])
                        return {'success': True, 'latency': latency, 'loss': loss}
        except:
            pass
        return {'success': False}
    
    def get_namespace_count(self):
        """Count network namespaces"""
        try:
            result = subprocess.run(['ip', 'netns', 'list'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                return len([l for l in result.stdout.strip().split('\n') if l])
        except:
            pass
        return 0
    
    def draw_dashboard(self, stdscr):
        """Draw the dashboard"""
        curses.curs_set(0)
        stdscr.nodelay(1)
        stdscr.timeout(100)
        
        # Initialize colors
        curses.start_color()
        curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
        curses.init_pair(2, curses.COLOR_RED, curses.COLOR_BLACK)
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)
        curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)
        curses.init_pair(5, curses.COLOR_MAGENTA, curses.COLOR_BLACK)
        
        while True:
            stdscr.clear()
            height, width = stdscr.getmaxyx()
            
            # Title
            title = "SD-WAN REAL-TIME DASHBOARD"
            stdscr.addstr(0, (width - len(title)) // 2, title, 
                         curses.A_BOLD | curses.color_pair(4))
            
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            stdscr.addstr(1, (width - len(current_time)) // 2, current_time)
            
            stdscr.addstr(2, 0, "═" * width, curses.color_pair(4))
            
            row = 4
            
            # Controller Status
            stdscr.addstr(row, 2, "SDN CONTROLLER STATUS:", curses.A_BOLD)
            row += 1
            
            controller = self.get_controller_status()
            if controller['running']:
                stdscr.addstr(row, 4, "● Status: RUNNING", curses.color_pair(1))
                stdscr.addstr(row, 30, f"PID: {controller['pid']}")
            else:
                stdscr.addstr(row, 4, "● Status: NOT RUNNING", curses.color_pair(2))
            
            row += 2
            
            # OVS Status
            stdscr.addstr(row, 2, "OPENVSWITCH STATUS:", curses.A_BOLD)
            row += 1
            
            ovs = self.get_ovs_status()
            if ovs['connected']:
                stdscr.addstr(row, 4, f"● Bridges: {len(ovs['bridges'])}", 
                            curses.color_pair(1))
                row += 1
                for bridge in ovs['bridges'][:4]:
                    flows = self.get_flow_stats(bridge)
                    stdscr.addstr(row, 6, f"├─ {bridge}: {flows} flows")
                    row += 1
            else:
                stdscr.addstr(row, 4, "● Status: DISCONNECTED", curses.color_pair(2))
                row += 1
            
            row += 1
            
            # Network Topology
            stdscr.addstr(row, 2, "NETWORK TOPOLOGY:", curses.A_BOLD)
            row += 1
            
            ns_count = self.get_namespace_count()
            stdscr.addstr(row, 4, f"● Namespaces: {ns_count}")
            row += 1
            stdscr.addstr(row, 4, f"● Sites: 3 (site1, site2, site3)")
            row += 1
            stdscr.addstr(row, 4, f"● Subnets: 10.1.0.0/24, 10.2.0.0/24, 10.3.0.0/24")
            
            row += 2
            
            # Link Status
            stdscr.addstr(row, 2, "INTER-SITE CONNECTIVITY:", curses.A_BOLD)
            row += 1
            
            # Test links
            test_pairs = [
                ('s1h1', '10.2.0.11', 'Site1 → Site2'),
                ('s1h1', '10.3.0.11', 'Site1 → Site3'),
                ('s2h1', '10.3.0.11', 'Site2 → Site3'),
            ]
            
            for source_ns, target_ip, label in test_pairs:
                result = self.ping_test_quick(source_ns, target_ip)
                
                if result['success']:
                    latency = result['latency']
                    loss = result['loss']
                    
                    if latency < 50 and loss < 1:
                        status_color = curses.color_pair(1)  # Green
                        status_symbol = "●"
                    elif latency < 100 and loss < 5:
                        status_color = curses.color_pair(3)  # Yellow
                        status_symbol = "●"
                    else:
                        status_color = curses.color_pair(2)  # Red
                        status_symbol = "●"
                    
                    stdscr.addstr(row, 4, status_symbol, status_color)
                    stdscr.addstr(row, 6, f"{label:20s}")
                    stdscr.addstr(row, 28, f"Latency: {latency:6.2f}ms  Loss: {loss:4.1f}%")
                else:
                    stdscr.addstr(row, 4, "●", curses.color_pair(2))
                    stdscr.addstr(row, 6, f"{label:20s}")
                    stdscr.addstr(row, 28, "UNREACHABLE", curses.color_pair(2))
                
                row += 1
            
            row += 2
            
            # Legend
            stdscr.addstr(row, 2, "LEGEND:", curses.A_BOLD)
            row += 1
            stdscr.addstr(row, 4, "● Excellent (<50ms, <1% loss)", curses.color_pair(1))
            row += 1
            stdscr.addstr(row, 4, "● Good (<100ms, <5% loss)", curses.color_pair(3))
            row += 1
            stdscr.addstr(row, 4, "● Poor (>100ms or >5% loss)", curses.color_pair(2))
            
            # Footer
            footer_row = height - 2
            stdscr.addstr(footer_row, 0, "─" * width, curses.color_pair(4))
            footer = "Press 'q' to quit | Refreshing every 2 seconds"
            stdscr.addstr(footer_row + 1, (width - len(footer)) // 2, footer, 
                         curses.color_pair(3))
            
            stdscr.refresh()
            
            # Check for quit
            key = stdscr.getch()
            if key == ord('q') or key == ord('Q'):
                break
            
            time.sleep(self.refresh_interval)
    
    def run(self):
        """Run the dashboard"""
        try:
            curses.wrapper(self.draw_dashboard)
        except KeyboardInterrupt:
            pass
        except Exception as e:
            print(f"Error: {e}")
            import traceback
            traceback.print_exc()


def main():
    print("Starting SD-WAN Dashboard...")
    print("Loading...")
    time.sleep(1)
    
    dashboard = SDWANDashboard()
    dashboard.run()
    
    print("\nDashboard closed.")


if __name__ == '__main__':
    main()
