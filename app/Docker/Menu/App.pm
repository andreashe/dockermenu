package Docker::Menu::App;

use strict;
use Carp;
use Try::Tiny;
use Log::VerySimple ':all';
use File::Slurp qw(write_file);
use YAML::Tiny;
use JSON;
# use File::Slurp qw(write_file);
use Data::Dumper;


# constructor
sub new{
    return bless {}, shift; # blessing on the hashed 
}
  
# before run, check some things
sub init{
  my $self = shift;

  $self->loadAppConfig();
  $self->loadProjectsConfig();


  $self->{running_containers} = $self->getCurrentDockerContainers();


  # hashmap to store values which
  # might be displayed in menu after a selection
  # keys: <name> => { value => "", data => {} }
  $self->{selection_data} = {};

  # load default project
  my $config_project_config = $self->findConfigProject();
  if (!$config_project_config){ # load first project if none given
    LOG->debug('select first project');
    $self->selectProject( $self->{projects}->[0] );  
  }else{ # load project from config
    $self->selectProject( $config_project_config );  
  }

}


# iterates the loaded projects and finds
# config by name.
sub findConfigProject{
  my $self = shift;

  my $projectname = $self->{config}->{current_project};
  if (!$projectname){return undef};

  LOG->debug("searching for project: $projectname");

  my $config = undef;

  foreach my $project (@{$self->{'projects'}}){
    my $title = $project->{'config'}->{'title'};

    if ($title eq $projectname){
      LOG->debug("found project: $projectname");
      $config = {
        config => $project->{config},
        path => $project->{path},
      };
    }
  }

  return $config;
}


# point to start
sub run{
  my $self = shift;

  my $menu = $self->getMainMenu();
  clear();
  $self->runMenu($menu);
  
}


# load this app config to $self->{'config'}
sub loadAppConfig{
  my $self = shift;  
  my $filepath = $ENV{"HOME"}.'/.dockermenu.yml';

  if (!-f $filepath){croak("Config file not found: $filepath")}

  LOG->debug("Loading app config: $filepath");

  my $yaml_obj = YAML::Tiny->read( $filepath ) or die $!;
  my $node = $yaml_obj->[0];

  # store config to memory
  $self->{'config'} = $node;
}


# saves the app config
sub writeAppConfig{
  my $self = shift;  
  my $filepath = $ENV{"HOME"}.'/.dockermenu.yml';

  if (!-f $filepath){croak("Config file not found: $filepath")}

  LOG->debug("Writing app config: $filepath");

  my $yaml = YAML::Tiny->new( $self->{config} );
  $yaml->write( $filepath );

}




# load projects profile data to $self->{'projects'} with
# config and path.
sub loadProjectsConfig{
  my $self = shift;  
  $self->{'projects'} = [];

  LOG->debug('loading project files ...');

  foreach my $projectpath ( @{$self->{config}->{projects}} ){
    
    my $filepath = "$projectpath/profile.yml";

    LOG->debug("loading project file: $filepath ...");

    if (!-f $filepath){croak "File does not exist: $filepath"}

    my $yaml_obj = YAML::Tiny->read( $filepath ) or die $!;
    my $node = $yaml_obj->[0];
    push(@{$self->{'projects'}}, {
      config => $node,
      path => $projectpath,
    })
  }
}


# returns the main menu as hashmap
sub getMainMenu{
  my $self = shift;

my $menu =  { 
                head  => 'Docker menu',
                nodes => [
                            { type => 'menu', key => 'p', title => 'select project',
                              menu => $self->getProjectMenu(),
                              selection => 'current_project'
                            },

                            { type => 'exec', key => 's', title => 'start container (inc build, force-recreate)', exec => \&startContainer },
                            { type => 'exec', key => 'o', title => 'stop  container', exec => \&stopContainer },
                            { type => 'exec', key => 'b', title => 'build container', exec => \&buildContainer },

                            { type => 'menu', key => 'd', title => 'deployment',
                                menu => {
                                    head => 'Deployment',
                                    nodes => [
                                        { type => 'nav',  key => 'q', title => '< back', cmd => 'return' },
                                        { type => 'exec', key => 'v', title => 'print current image version', exec => \&printImageVersion },
                                        { type => 'exec', key => 'p', title => 'increase images version - patch', exec => \&increaseImageVersionPatch },
                                        { type => 'exec', key => 'r', title => 'increase images version - release', exec => \&increaseImageVersionRelease },
                                        { type => 'exec', key => 's', title => 'push image - snapshot', exec => \&pushImageSnapshot },
                                        { type => 'exec', key => 'e', title => 'push image - release', exec => \&pushImageRelease },
                                    ]
                                }
                            },

                            { type => 'menu', key => 'x', title => 'linux shell',
                                menu => {
                                    head => 'linux shell',
                                    nodes => $self->get_profile_menu_ssh(),
                                }
                            },


                            { type => 'menu', key => 'l', title => 'show logs',
                                menu => {
                                    head => 'show logs',
                                    nodes => $self->get_profile_menu_logs(),
                                }
                            },

                            { type => 'menu', key => 'm', title => 'maintenance',
                                menu => {
                                    head => 'Maintenance',
                                    nodes => [
                                        { type => 'nav',  key => 'q', title => '< back', cmd => 'return' },
                                        { type => 'exec', key => 'o', title => 'stop all containers', exec => \&stopAllDockerContainers },
                                        { type => 'exec', key => 'r', title => 'remove all containers', exec => \&removeAllDockerContainers },
                                        { type => 'exec', key => 'p', title => 'full prune docker', exec => \&pruneDocker },
                                        { type => 'exec', key => 'u', title => 'update compose file', exec => \&updateComposeFile},
                                    ]
                                }
                            },


                            { type => 'exec', key => 'q', title => 'quit', exec => \&exitApp },
                          ]
            };


  return $menu;
}



# Menu to select current project
sub getProjectMenu{
  my $self = shift;

  my $menu = {
    head => 'select project',
    nodes => [],
  };

  # back step entry
  push(@{$menu->{'nodes'}}, { type => 'nav',  key => 'q', title => '< back', cmd => 'return' });

  my $key = 1;
  foreach my $project (@{$self->{'projects'}}){
    my $entry = {
      type => 'exec',
      key => $key,
      title => $project->{'config'}->{'title'},
      exec => \&selectProject,
      data => $project
    };
    $key++;

    push(@{$menu->{'nodes'}}, $entry);
  }



  return $menu;
}


# uses the docker command to get a list of current running containers as nodes
#
# the output of the docker ls command and text edit after it looks like this:
# $VAR1 = [
#           {
#             'LocalVolumes' => '1',
#             'RunningFor' => '4 weeks ago',
#             'Ports' => '0.0.0.0:6379->6379/tcp',
#             'Size' => '68B (virtual 113MB)',
#             'Image' => 'redis',
#             'Status' => 'Up 20 hours',
#             'Mounts' => "123da6f108c2fd\x{2026}",
#             'Names' => 'cop-redis',
#             'CreatedAt' => '2021-12-21 08:53:57 +0100 CET',
#             'ID' => '9a571e13eea2',
#             'Networks' => 'bridge',
#             'State' => 'running',
#             'Command' => "\"docker-entrypoint.s\x{2026}\"",
#             'Labels' => ''
#           },
#           {
#             'Image' => 'postgres',
#             'Status' => 'Up 11 minutes',
#             'Mounts' => "8626b9a9ca02f7\x{2026}",
#             'Names' => 'cop-postgres',
#             'LocalVolumes' => '1',
#             'RunningFor' => '5 weeks ago',
#             'Ports' => '0.0.0.0:5432->5432/tcp',
#             'Size' => '63B (virtual 374MB)',
#             'State' => 'running',
#             'Command' => "\"docker-entrypoint.s\x{2026}\"",
#             'Labels' => '',
#             'CreatedAt' => '2021-12-13 10:42:08 +0100 CET',
#             'Networks' => 'bridge',
#             'ID' => 'cd77c16c5ab4'
#           }
#         ];
sub getCurrentDockerContainers{
  my $self = shift;

    my $json_text = `docker container ls --format='{{json .}},'`;
    $json_text = '['.$json_text.']'; # add array brackets
    $json_text =~ s/[\n\l]//g; # remove returns
    $json_text =~ s/,\]$/]/; # remove last comma

    my $docker_containers = decode_json $json_text;

    return $docker_containers;
}


# creating the menu for shell. It adds the current project and
# all running docker containers
sub get_profile_menu_ssh{
  my $self = shift;
  my @menu;

  push @menu, { type => 'nav',  key => 'q', title => '< back', cmd => 'return' };


  push @menu, { type => 'exec', key => 'p', title => sprintf("open linux shell to current project: %s", $self->{current_project}->{config}->{title}, ), exec => \&openLinuxShellToDockerByContainer, data => {container => $self->{current_project}->{config}->{container} } };


  my $docker_containers = $self->{running_containers}; # created in constructor, not updated

  my $c=0;
  foreach my $container_node (@$docker_containers){
      $c++;
      my $container = $container_node->{Names};
      
      push @menu, { type => 'exec', key => $c, title => sprintf("open linux shell to: %s", $container), exec => \&openLinuxShellToDockerByContainer, data => { container => $container } },
  }


  return \@menu;
}


# creating the menu for logs. It adds the current project and
# all running docker containers
sub get_profile_menu_logs{
  my $self = shift;
  my @menu;

  push @menu, { type => 'nav',  key => 'q', title => '< back', cmd => 'return' };


  push @menu, { type => 'exec', key => 'p', title => sprintf("show logs of current project: %s", $self->{current_project}->{config}->{title}, ), exec => \&showLogsOfDockerContainer, data => {container => $self->{current_project}->{config}->{container} } };


  my $docker_containers = $self->{running_containers}; # created in constructor, not updated

  my $c=0;
  foreach my $container_node (@$docker_containers){
      $c++;
      my $container = $container_node->{Names};
      
      push @menu, { type => 'exec', key => $c, title => sprintf("show logs of: %s", $container), exec => \&showLogsOfDockerContainer, data => { container => $container } },
  }


  return \@menu;
}



# prints the log of a container
sub showLogsOfDockerContainer{
  my $self = shift;
  my $param = shift;
  my $container = $param->{'container'} or die "container missing";

  runCmd("docker logs $container");
}




# opens a shell to a docker container (linux inside)
# param is made to be called from menu data key like:
# data => { key => 'value' }
sub openLinuxShellToDockerByContainer{
  my $self = shift;
  my $param = shift;
  my $container = $param->{'container'} or die "container missing";

  print "To exit shell, enter 'exit'\n";
  runCmd("winpty docker exec -it $container env bash");
}


# used by menu to select a project.
# a project is a hashmap with path and config (profile).
sub selectProject{
  my $self = shift;
  
  # for global usage
  $self->{current_project} = shift;

  # to show selection in menu
  $self->{selection_data}->{current_project} = {
    value => $self->{current_project}->{config}->{title},
    data => $self->{current_project}
  };
  # print Dumper($self->{selection_data});

  # save the selected project to config to load it directly after restart
  $self->{config}->{current_project} = $self->{current_project}->{config}->{title};
  $self->writeAppConfig();
}


# returns the path of the selected project
sub currentProjectPath{
    my $self = shift;

    return $self->{current_project}->{path};
}


# clears the screen
sub clear{
  system("clear");
}


# run a command and logs
sub runCmd{
    my $cmd = shift || die "requires command";

    LOG->info("CMD: $cmd");

    system( $cmd );
}


# Starts docker-compose of selected project
# docker-compose up --build --force-recreate
sub startContainer{
    my $self = shift;
    my $path = $self->currentProjectPath();

    $self->updateComposeFile();

    chdir($path);
    runCmd('docker-compose up --build --detach');
    #runCmd('docker-compose up --build --force-recreate --detach');
}



# just builds image with docker-compose of selected project
sub buildContainer{
    my $self = shift;
    my $path = $self->currentProjectPath();

    $self->updateComposeFile();

    chdir($path);
    runCmd('docker-compose build --parallel');
}



sub updateComposeFile{
  my $self = shift;
  $self->rebuildDockerCompose();
  $self->updateComposeImageStrings();  
}


# publishes a snapshot
# "snapshot" is the default way
sub pushImageSnapshot{
  my $self = shift;
  my $path = $self->currentProjectPath();

  $self->updateComposeFile();

  chdir($path);
  runCmd('docker-compose build');
  runCmd('docker-compose push');
}


sub pushImageRelease{
  my $self = shift;
  my $path = $self->currentProjectPath();

  $self->updateComposeFile();
  # set a release url
  $self->updateComposeImageStrings(repository => 'release' );

  chdir($path);

  runCmd('docker-compose build');
  runCmd('docker-compose push');

  # return to snapshot
  $self->updateComposeImageStrings(repository => 'snapshot' );
}





# Stops docker-compose project of selected project
sub stopContainer{
    my $self = shift;
    my $path = $self->currentProjectPath();

    chdir($path);
    runCmd('docker-compose down');
}


# prints the image version of current project
sub printImageVersion{
  my $self = shift;
  system("clear");

  my $node = $self->getDeploymentSettings();

  print sprintf("\n\nCurrent version: %s\n\n", $node->{'version'} );
}


# full prune of docker. Removes all cached data
sub pruneDocker{
  my $self = shift;
  my $path = $self->currentProjectPath();

  chdir($path);
  runCmd('docker-compose down --remove-orphans'); # nice shutdown of current project
  
  runCmd('docker kill $(docker ps -q)'); # stop all other containers
  runCmd('docker rm $(docker ps -a -q)'); # remove all other containers
  runCmd('docker volume rm $(docker volume ls -q)'); # remove volumes
  runCmd('docker system prune -af'); # prune all
}


# stop all running containers
sub stopAllDockerContainers{
  my $self = shift;
  my $path = $self->currentProjectPath();

  chdir($path);
  runCmd('docker-compose down'); # nice shutdown of current project
  runCmd('docker kill $(docker ps -q)'); # stop all other containers
}


# remove all running containers
sub removeAllDockerContainers{
  my $self = shift;
  my $path = $self->currentProjectPath();

  chdir($path);
  runCmd('docker-compose down'); # nice shutdown of current project
  runCmd('docker kill $(docker ps -q)'); # stop all other containers
  runCmd('docker rm $(docker ps -a -q)'); # remove all other containers
}



# increases the last number of e.g. 1.1.1 to 1.1.2
# which is in the deployment file and writes it back
sub increaseImageVersionPatch(){
  my $self = shift;

  my $path = $self->currentProjectPath();
  my $deploymentFile = "$path/deployment.yml";

  my $yaml_obj = YAML::Tiny->read( $deploymentFile ) or die $!;
  my $settings = $yaml_obj->[0];
  my $version = $settings->{'version'};

  $version =~ s/(\d+)\.(\d+)\.(\d+)/ 
   my $c = $3;
   $c++;
   $_="$1.$2.$c";
  /e;
  
  $settings->{version} = $version;

  $yaml_obj->write( $deploymentFile );

  $self->updateComposeImageStrings();

  $self->printImageVersion();
}


# increases the middle number of e.g. 1.1.1 to 1.2.1
# which is in the deployment file and writes it back
sub increaseImageVersionRelease(){
  my $self = shift;

  my $path = $self->currentProjectPath();
  my $deploymentFile = "$path/deployment.yml";

  my $yaml_obj = YAML::Tiny->read( $deploymentFile ) or die $!;
  my $settings = $yaml_obj->[0];
  my $version = $settings->{'version'};

  $version =~ s/(\d+)\.(\d+)\.(\d+)/ 
   my $c = $2;
   $c++;
   $_="$1.$c.1";
  /e;
  
  $settings->{version} = $version;

  $yaml_obj->write( $deploymentFile );

  $self->updateComposeImageStrings();

  $self->printImageVersion();
}



# Takes the profile and merges it to compose file using the "compose" section
sub rebuildDockerCompose{
    my $self = shift;
    my $path = $self->currentProjectPath();
    my $composefile = "$path/docker-compose.yml";

    my $yaml_obj = YAML::Tiny->read( $composefile ) or die $!;
    my $compose = $yaml_obj->[0];

    # remove existing services
    $compose->{"services"} = {};

    $compose->{"services"}->{ $self->{current_project}->{config}->{service} } = $self->{current_project}->{config}->{compose}; # copy compose part
   
    # this is a hack as docker-compose requires quotes around the ports
    my $text = $yaml_obj->write_string($composefile);
    $text =~ s/(\d{2,5}:\d{2,5})/\"$1\"/gs;

    write_file($composefile, $text);
}



# reads the deployment file
sub getDeploymentSettings(){
    my $self = shift;
    my $path = $self->currentProjectPath();
    my $deploymentFile = "$path/deployment.yml";

    my $yaml_obj = YAML::Tiny->read( $deploymentFile ) or die $!;
    
    return $yaml_obj->[0];
}





# takes a compose hash and replaces the image strings
# with a new one created, using the deployment server 
# can build a string like: snapshot.nexus.domain.de/test/myhello:1.1.4-SNAPSHOT
#
# optional paramter:
#   repository: "snapshot"
sub updateComposeImageStrings{
    my $self = shift;
    my $param = {@_};
    my $repository = $param->{'repository'} || 'snapshot';

    my $path = $self->currentProjectPath();
    my $composefile = "$path/docker-compose.yml";


    my $versionappendix = $repository eq 'snapshot' ? "-SNAPSHOT" : "";

    my $dsettings = $self->getDeploymentSettings();
    my $version = $dsettings->{"version"};

    my $location = $dsettings->{"repository"}->{$repository};

    my $yaml_obj = YAML::Tiny->read( $composefile ) or die $!;
    my $compose = $yaml_obj->[0];



    # if in profile is a dockerfile used, update the image
    

    my $profile = $self->{current_project}->{config};

      if (exists $profile->{'compose'}->{"build"}->{"dockerfile"}){

          my $pimage = $profile->{'compose'}->{"image"};
          my $image = sprintf("%s/%s:%s%s", $location, $pimage, $version, $versionappendix);
          
          $compose->{"services"}->{ $profile->{"service"} }->{"image"} = $image;

      }

  

   
    # this is a hack as docker-compose requires quotes around the ports
    my $text = $yaml_obj->write_string($composefile);
    $text =~ s/(\d{2,5}:\d{2,5})/\"$1\"/gs;
    write_file($composefile, $text);
}



# renders the menu. Requires a special structure.
sub showMenu{
  my $self = shift;
  my $menu = shift;

  print "\n";
  print sprintf(" %s\n", $menu->{head});
  print " ";
  print "=" x length($menu->{head});
  print "\n";

  my $nodes = $menu->{'nodes'};

  # show 
  foreach my $node (@$nodes){
      my $type = $node->{'type'};
      my $key = $node->{'key'};
      my $title = $node->{'title'};
      my $selection = $node->{'selection'};

      if ($type =~ /^(exec|menu|nav)$/){
        if ($selection){ 
          print sprintf(" [%s] %s   ( %s )\n", $key, $title, $self->{selection_data}->{$selection}->{value} );
        }else{
          print sprintf(" [%s] %s\n", $key, $title);
        }
      }
  }

  print "\n";
}



# takes a menu-selection and returns it
sub selectMenu{
  my $self = shift;

  my $in = undef;

  do{
      print "SELECT> ";
      $in = <STDIN>;

      # trim
      $in =~ s/^\s+//;
      $in =~ s/\s+$//;
      $in = lc($in);

      $in=$in || undef;

      # if ($in && ($in !~ m/^[tsqpux12\.]$/)){
      #     $in = undef;
      # }

  } until ($in);

  return $in;
}



# runs the menu
sub runMenu{
  my $self = shift;
  my $menu = shift;
  $self->showMenu($menu);

  my $nodes = $menu->{'nodes'};

  my $LOOP = 1;

  while($LOOP){
      my $sel = $self->selectMenu();

      foreach my $node (@$nodes){
          my $type = $node->{'type'};
          my $key = $node->{'key'}; 

          if ($key eq $sel){  
              if ($type eq 'exec'){ 
                  # executes a reference to a method
                  # takes data from node
                  &{$node->{exec}}( $self, $node->{data} );           
                  $self->showMenu($menu); 
              }
              if ($type eq 'menu'){ 
                  system("clear"); # cls
                  $self->runMenu( $node->{'menu'} ); 
                  $self->showMenu($menu);
                  }

              if ($type eq 'nav'){
                  system("clear"); # cls
                  if ($node->{'cmd'} eq 'return'){$LOOP=0};
              }
          }


      }
  }
    
}


sub exitApp{
    exit;
}

1;