from dataclasses import dataclass
@dataclass(frozen=True)
class Checkout: cart_id:str;items:int;total:float
def parse_checkout(value):
    cart_id=str(value.get("cartId","")).strip().upper();items=value.get("items");total=value.get("total")
    if not 4<=len(cart_id)<=64:raise ValueError("INVALID_CART")
    if not isinstance(items,int) or not 1<=items<=100:raise ValueError("INVALID_ITEMS")
    if not isinstance(total,(int,float)) or not 0<float(total)<=1_000_000:raise ValueError("INVALID_TOTAL")
    return Checkout(cart_id,items,float(total))
