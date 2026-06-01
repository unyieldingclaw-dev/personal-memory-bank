import subprocess

# Bad: user input passed directly to shell (SEC-002)
def run_command(user_input):
    result = subprocess.run(user_input, shell=True, capture_output=True)
    return result.stdout

def ping_host(hostname):
    output = subprocess.check_output("ping -c 1 " + hostname, shell=True)
    return output
