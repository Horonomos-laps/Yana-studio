-- The button on the disk image: asks once, runs update.sh from its own Resources, opens the new Yana.
on run
	set installed to "/Applications/Yana.app"
	set scriptPath to POSIX path of (path to resource "update.sh")
	set helper to POSIX path of (path to me)
	set newApp to do shell script "printf '%s/Yana.app' \"$(dirname " & quoted form of helper & ")\""
	display dialog "Cập nhật Yana lên bản mới?" & return & "Cài đặt, lịch sử chat và khóa API được giữ nguyên. Bản cũ vào Thùng rác." & return & return & "Update Yana? Your settings, chats and keys stay. The old version goes to the Trash." buttons {"Hủy", "Cập nhật"} default button "Cập nhật" cancel button "Hủy" with title "Yana"
	try
		do shell script "/bin/bash " & quoted form of scriptPath & " " & quoted form of newApp & " " & quoted form of installed
	on error message number code
		if code is 3 then
			display dialog "Hãy thoát Yana và Yana Studio, rồi bấm lại nút này." & return & "Quit Yana and Yana Studio, then press this button again." buttons {"OK"} default button "OK" with title "Yana"
		else
			display dialog "Chưa cập nhật được. Bạn có thể kéo Yana vào Applications." & return & "Could not update. Drag Yana into Applications instead." & return & return & message buttons {"OK"} default button "OK" with title "Yana"
		end if
		return
	end try
	do shell script "open " & quoted form of installed
	display dialog "Đã cập nhật xong." & return & "Yana is up to date." buttons {"OK"} default button "OK" with title "Yana" giving up after 8
end run
