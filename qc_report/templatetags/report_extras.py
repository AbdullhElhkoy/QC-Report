from django import template

register = template.Library()


@register.filter
def index(lst, i):
    """يرجع عنصر بالفهرس من قائمة داخل القالب (أو None لو بره النطاق)."""
    try:
        return lst[int(i)]
    except (IndexError, TypeError, ValueError):
        return None
