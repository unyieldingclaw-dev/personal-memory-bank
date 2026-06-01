# Bad: eval/exec with user-controlled input (SEC-009)
def calculate(expression):
    result = eval(expression)
    return result

def run_script(code):
    exec(code)

def dynamic_call(func_name, args):
    import os
    os.system(func_name + " " + args)
