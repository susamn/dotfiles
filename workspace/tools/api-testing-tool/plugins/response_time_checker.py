# Sample Plugin - Response Time Checker
# This plugin checks if response time is acceptable

if response_data:
    response_time = response_data.get('response_time', 0)
    if response_time > 2000:  # 2 seconds
        result = f"WARNING: Slow response time: {response_time:.2f}ms"
    else:
        result = f"OK: Response time: {response_time:.2f}ms"
else:
    result = "No response data available"
