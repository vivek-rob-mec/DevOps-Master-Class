output "folder_id" { value = google_folder.platform.name }
output "project_ids" { value = { for key, project in google_project.platform : key => project.project_id } }
