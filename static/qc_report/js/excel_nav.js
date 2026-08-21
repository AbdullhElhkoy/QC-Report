/* تنقل بين خلايا الإدخال بأسهم الكيبورد و Enter — زي شيت الإكسيل
   Enter / سهم تحت → الخلية اللي تحت | سهم فوق → فوق | يمين/شمال → يمين وشمال فيزيائياً */
(function () {
  document.addEventListener("DOMContentLoaded", function () {
    var form = document.querySelector("form");
    if (!form) return;
    var selector =
      "input:not([type=hidden]):not([type=submit]):not([readonly]):not([disabled]), textarea:not([readonly]):not([disabled])";
    var inputs = Array.prototype.slice
      .call(form.querySelectorAll(selector))
      .filter(function (el) {
        return el.offsetParent !== null;
      });
    if (!inputs.length) return;

    var COL_TOL = 40, ROW_TOL = 15;

    var xs = [], ys = [];
    inputs.forEach(function (el) {
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width / 2, y = r.top;
      if (!xs.some(function (v) { return Math.abs(v - cx) < COL_TOL; })) xs.push(cx);
      if (!ys.some(function (v) { return Math.abs(v - y) < ROW_TOL; })) ys.push(y);
    });
    xs.sort(function (a, b) { return a - b; });
    ys.sort(function (a, b) { return a - b; });

    function cellOf(el) {
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width / 2, y = r.top, c = 0, rr = 0;
      var bestC = Infinity, bestR = Infinity;
      xs.forEach(function (v, i) {
        var d = Math.abs(v - cx);
        if (d < bestC) { bestC = d; c = i; }
      });
      ys.forEach(function (v, i) {
        var d = Math.abs(v - y);
        if (d < bestR) { bestR = d; rr = i; }
      });
      return { r: rr, c: c };
    }

    function focusCell(row, col) {
      if (row < 0 || col < 0 || row >= ys.length || col >= xs.length) return false;
      var tx = xs[col], ty = ys[row];
      var target = null;
      for (var i = 0; i < inputs.length; i++) {
        var rc = inputs[i].getBoundingClientRect();
        if (
          Math.abs(rc.left + rc.width / 2 - tx) < COL_TOL &&
          Math.abs(rc.top - ty) < ROW_TOL
        ) {
          target = inputs[i];
          break;
        }
      }
      if (target) target.focus();
      return !!target;
    }

    function focusSave() {
      var btn = form.querySelector('button[type="submit"]');
      if (btn) btn.focus();
    }

    inputs.forEach(function (el) {
      // عند الوقوف على خلية حدد محتواها كله زي إكسيل عشان الكتابة فوقه على طول
      el.addEventListener("focus", function () {
        if (el.select && !/TEXTAREA/i.test(el.tagName)) {
          try { el.select(); } catch (e) {}
        }
      });
      el.addEventListener("keydown", function (ev) {
        var pos = cellOf(el);
        switch (ev.key) {
          case "Enter":
            ev.preventDefault();
            if (!focusCell(pos.r + 1, pos.c) && pos.r === ys.length - 1) focusSave();
            break;
          case "ArrowDown":
            ev.preventDefault();
            focusCell(pos.r + 1, pos.c);
            break;
          case "ArrowUp":
            ev.preventDefault();
            focusCell(pos.r - 1, pos.c);
            break;
          case "ArrowRight":
            ev.preventDefault();
            focusCell(pos.r, pos.c + 1);
            break;
          case "ArrowLeft":
            ev.preventDefault();
            focusCell(pos.r, pos.c - 1);
            break;
        }
      });
    });
  });
})();
