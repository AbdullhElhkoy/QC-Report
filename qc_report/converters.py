from datetime import datetime


class DateConverter:
    regex = r"\d{4}-\d{2}-\d{2}"

    def to_python(self, value):
        return datetime.strptime(value, "%Y-%m-%d").date()

    def to_url(self, value):
        return value.strftime("%Y-%m-%d")
