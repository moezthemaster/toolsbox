import win32process
import win32con
import win32file
import win32event
import win32api
import win32security

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

# Création d'un objet processus avec les informations d'identification
try:
    process = win32process.CreateProcessWithLogonW(username, None, password,
                                                win32process.LOGON_WITH_PROFILE | win32process.LOGON_NETCREDENTIALS_ONLY,
                                                None, command, None, None, si)
except pywintypes.error as ex:
    # Gestion des erreurs éventuelles
print(f"Erreur : {ex}")
