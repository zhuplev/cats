</div>
<table class="iface">
<tr bgcolor="#7070ff" style="height: 30px" class="top">
  <td class="signed">
    ������� ������������: 
    <TMPL_IF current_team_name><TMPL_VAR current_team_name ESCAPE=HTML>
    <TMPL_ELSE>���������</TMPL_IF>
  </td>
  <td align="right">
    <a href="../bugs/" class="signed">Bugzilla</a> |
    <a href="docs/" class="signed">������������</a> |
    <a href="<TMPL_VAR url_authors>" class="signed">&copy; 2002-2009 ������</a>&nbsp;
  </td>
</tr>
<tr bgcolor="#ffcc55" style="height: 40px">
  <td style="background-image: url(./images/std/bg2.gif)" class="down">
    &nbsp;<font size="-3" color="#808080"><TMPL_VAR request_process_time> <TMPL_VAR init_time></font>
  </td>
  <td align="right">
	<a href="http://imcs.dvgu.ru" class="signed2"> �������� ���������� � ������������ ����&nbsp;<br> ��������������� ��������������� ����������� &nbsp;</a>
  </td>
</tr>
</table>
</body>
</html>
