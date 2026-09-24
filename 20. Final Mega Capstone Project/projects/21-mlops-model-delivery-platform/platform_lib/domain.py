import math
FEATURE_COUNT=4
def validate_features(values):
    if not isinstance(values,list) or len(values)!=FEATURE_COUNT:raise ValueError("INVALID_FEATURE_COUNT")
    parsed=[]
    for value in values:
        if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(float(value)):raise ValueError("INVALID_FEATURE")
        parsed.append(float(value))
    return parsed
