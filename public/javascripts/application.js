$(function() {
  $("form.delete").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      this.submit();
    }
  });

  $("form.duplicate").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("WARNING: The duplicate file's name has not been changed.This will overwrite the current file of the same name. Continue?");
    if (ok) {
      this.submit();
    }
  });
});