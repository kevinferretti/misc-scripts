Install-Module Microsoft.Graph -Scope CurrentUser

Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory

$managedIdentityId = "<object ID>"
$roleName = "Application.Read.All"

$msgraph = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
$role = $Msgraph.AppRoles | Where-Object { $_.Value -eq $roleName } 

New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -PrincipalId $managedIdentityId -ResourceId $msgraph.Id -AppRoleId $role.Id
 
Disconnect-MgGraph
