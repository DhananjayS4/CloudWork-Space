import Notes from "../components/Notes";
import Tasks from "../components/Tasks";
import FileManager from "../components/FileManager";

function Dashboard() {
  return (
    <div>
      <h1>My Cloud Workspace</h1>
      <Notes />
      <Tasks />
      <FileManager />
    </div>
  );
}
export default Dashboard;
