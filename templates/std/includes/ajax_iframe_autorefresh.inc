<TMPL_UNLESS printable>
<script>
    var a = top.document;
    a.getElementById('server_time').innerHTML = "<font color='green'><TMPL_VAR server_time></font>";
    if (a.getElementById('elapsed_minutes') != null)
        a.getElementById('elapsed_minutes').innerHTML = "<TMPL_VAR elapsed_minutes>";
    a.getElementById('refreshable_content').innerHTML =
        document.getElementById('refreshable_content').innerHTML;
    setTimeout('document.location.reload(1);', 5000);
</script>
</TMPL_UNLESS>