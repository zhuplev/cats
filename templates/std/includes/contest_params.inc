<table cellpadding="0">
  <tr><td>�������� ����������:</td><td><input type="text" size="50" name="contest_name" value="<TMPL_VAR contest_name ESCAPE=HTML>" class="bordered" <TMPL_UNLESS can_edit>readonly="readonly"</TMPL_UNLESS>/></td></tr>
  <tr><td>����/����� ������:</td><td><input type="text" name="start_date" value="<TMPL_VAR start_date ESCAPE=HTML>" class="bordered" <TMPL_UNLESS can_edit>readonly="readonly"</TMPL_UNLESS>/></td></tr>
  <tr><td>����/����� ��������� ������� �����������:</td><td><input type="text" name="freeze_date" value="<TMPL_VAR freeze_date ESCAPE=HTML>" class="bordered" <TMPL_UNLESS can_edit>readonly="readonly"</TMPL_UNLESS>/></td></tr>
  <tr><td>����/����� ������:</td><td><input type="text" name="finish_date" value="<TMPL_VAR finish_date ESCAPE=HTML>" class="bordered" <TMPL_UNLESS can_edit>readonly="readonly"</TMPL_UNLESS>/></td></tr>
  <tr><td>����/����� �������� ������� � �����������:</td><td><input type="text" name="open_date" value="<TMPL_VAR open_date ESCAPE=HTML>" class="bordered" <TMPL_UNLESS can_edit>readonly="readonly"</TMPL_UNLESS>/></td></tr>
  <tr><td>������� ������:</td><td><TMPL_IF can_edit>
    <select name="rules" class="bordered">
      <option value="0"<TMPL_UNLESS rules> selected="selected"</TMPL_UNLESS>>ACM</option>
      <option value="1"<TMPL_IF rules> selected="selected"</TMPL_IF>>��������</option>
    </select><TMPL_ELSE><TMPL_IF rules>��������<TMPL_ELSE>ACM</TMPL_IF>
    </TMPL_IF>
  </td></tr>
  <tr><td>������������ ����� �������:</td><td><input type="text" name="max_reqs" value="<TMPL_VAR max_reqs ESCAPE=HTML>" class="bordered" <TMPL_UNLESS can_edit>readonly="readonly"</TMPL_UNLESS>/></td></tr>
</table>
<br/>
<table cellpadding="0" class="bordered" width="250">
  <tr><td>��������� �����������:</td><td><input type="checkbox" name="free_registration"<TMPL_IF free_registration>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>����������� ������:</td><td><input type="checkbox" name="is_official"<TMPL_IF is_official>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>��������� ��� �����:</td><td><input type="checkbox" name="run_all_tests"<TMPL_IF run_all_tests>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>������ ��������� ���������:</td><td><input type="checkbox" name="local_only"<TMPL_IF local_only>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>�������:</td><td><input type="checkbox" name="is_hidden"<TMPL_IF is_hidden>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
</table>
<br/>
���������� ����������
<table cellpadding="0" class="bordered" width="250">
  <tr><td>��� ����������:</td><td><input type="checkbox" name="show_all_tests"<TMPL_IF show_all_tests>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>�������������� �������:</td><td><input type="checkbox" name="show_test_resources"<TMPL_IF show_test_resources>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>����������� checker'�:</td><td><input type="checkbox" name="show_checker_comment"<TMPL_IF show_checker_comment>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
  <tr><td>������ �����:</td><td><input type="checkbox" name="show_packages"<TMPL_IF show_packages>checked="checked"</TMPL_IF> <TMPL_UNLESS can_edit>disabled="disabled"</TMPL_UNLESS>/></td></tr>
</table>
<br/>
