REQUIRED_CONTROLS={"strict_mtls","default_deny","explicit_allow","bounded_timeout","telemetry"}

def evaluate(control_sets:dict[str,set[str]])->dict[str,list[str]]:
    if not control_sets:
        raise ValueError("at least one namespace is required")
    return {namespace:sorted(REQUIRED_CONTROLS-controls) for namespace,controls in control_sets.items()}

def promotion_allowed(control_sets:dict[str,set[str]])->bool:
    return all(not missing for missing in evaluate(control_sets).values())

def trust_domains_compatible(primary:str,remote:str,aliases:set[str])->bool:
    return primary==remote or remote in aliases
