import win32process
import win32con
import win32file
import win32event
import win32api

username = "username"
# Nom d'utilisateur de l'administrateur
password = "password"
# Mot de passe de l'administrateur
command = r"powershell F:\labodro\proc\script.ps1"
# Commande PowerShell à exécuter
# Création d'un processus en tant qu'administrateur
si = win32process.STARTUPINFO()
si.dwFlags = win32process.STARTF_USESTDHANDLES | win32process.STARTF_USESHOWWINDOW
si.hStdInput = win32api.GetStdHandle(win32api.STD_INPUT_HANDLE)
si.hStdOutput = win32api.GetStdHandle(win32api.STD_OUTPUT_HANDLE)
si.hStdError = win32api.GetStdHandle(win32api.STD_ERROR_HANDLE)
si.wShowWindow = win32con.SW_HIDE

# Création d'un objet processus
process = win32process.CreateProcess(None,
                                    f"runas /user:{username} \"{command}\"",
                                    None, None, 0, 0, None, None, si)

# Envoi du mot de passe à la fenêtre de `runas`
win32api.SendMessageTimeout(process[0], win32con.WM_SETTEXT, password, 0, 0)
win32api.SendMessageTimeout(process[0], win32con.WM_KEYDOWN, win32con.VK_RETURN, 0, 0)
