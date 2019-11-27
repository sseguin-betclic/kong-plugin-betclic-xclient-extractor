#load "nuget:?package=ContinuousDelivery.Cake.Addins"

var target = Argument("Target", "Default");

Task("Default")
    .IsDependentOn(TasksLibrary.Directories.Clean)
    .IsDependentOn(TasksLibrary.Nuget.Pack)
    .IsDependentOn(TasksLibrary.Octopus.Push)
    .IsDependentOn(TasksLibrary.Octopus.CreateRelease);

RunTarget(target);
