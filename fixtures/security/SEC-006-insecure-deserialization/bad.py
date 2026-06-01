import pickle
import yaml

# Bad: deserializing untrusted data (SEC-006)
def load_user_session(cookie_data):
    return pickle.loads(cookie_data)

def load_config(config_string):
    # Missing Loader= argument
    return yaml.load(config_string)

def restore_object(serialized):
    return pickle.loads(serialized)
