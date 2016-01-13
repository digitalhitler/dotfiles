


## Git completion
# fish completion for git
# Use 'command git' to avoid interactions for aliases from git to (e.g.) hub

function __fish_git_commits
  # Complete commits with their subject line as the description
  # This allows filtering by subject with the new pager!
  # Because even subject lines can be quite long,
  # trim them (abbrev'd hash+tab+subject) to 70 characters
  command git log --pretty=tformat:"%h"\t"%s" --all \
  | string replace -r '(.{70}).+' '$1...'
end

function __fish_git_branches
  command git branch --no-color -a ^/dev/null | __fish_sgrep -v ' -> ' | string trim -c "* " | string replace -r "^remotes/" ""
end

function __fish_git_unique_remote_branches
  # Allow all remote branches with one remote without the remote part
  # This is useful for `git checkout` to automatically create a remote-tracking branch
  command git branch --no-color -a ^/dev/null | __fish_sgrep -v ' -> ' | string trim -c "* " | string replace -r "^remotes/[^/]*/" "" | sort | uniq -u
end

function __fish_git_tags
  command git tag ^/dev/null
end

function __fish_git_heads
  __fish_git_branches
  __fish_git_tags
end

function __fish_git_remotes
  command git remote ^/dev/null
end

function __fish_git_modified_files
  # git diff --name-only hands us filenames relative to the git toplevel
  set -l root (command git rev-parse --show-toplevel)
  # Print files from the current $PWD as-is, prepend all others with ":/" (relative to toplevel in git-speak)
  # This is a bit simplistic but finding the lowest common directory and then replacing everything else in $PWD with ".." is a bit annoying
  string replace -- "$PWD/" "" "$root/"(command git diff --name-only ^/dev/null) | string replace "$root/" ":/"
end

function __fish_git_staged_files
  set -l root (command git rev-parse --show-toplevel)
  string replace -- "$PWD/" "" "$root/"(command git diff --staged --name-only ^/dev/null) | string replace "$root/" ":/"
end

function __fish_git_add_files
  set -l root (command git rev-parse --show-toplevel)
  string replace -- "$PWD/" "" "$root/"(command git -C $root ls-files -mo --exclude-standard ^/dev/null) | string replace "$root/" ":/"
end

function __fish_git_ranges
  set -l both (commandline -ot | string split "..")
  set -l from $both[1]
  # If we didn't need to split (or there's nothing _to_ split), complete only the first part
  # Note that status here is from `string split` because `set` doesn't alter it
  if test -z "$from" -o $status -gt 0
    __fish_git_heads
    return 0
  end

  set -l to (set -q both[2]; and echo $both[2])
  for from_ref in (__fish_git_heads | string match "$from")
    for to_ref in (__fish_git_heads | string match "*$to*") # if $to is empty, this correctly matches everything
      printf "%s..%s\n" $from_ref $to_ref
    end
  end
end

function __fish_git_needs_command
  set cmd (commandline -opc)
  if [ (count $cmd) -eq 1 ]
    return 0
  else
    set -l skip_next 1
    # Skip first word because it's "git" or a wrapper
    for c in $cmd[2..-1]
      test $skip_next -eq 0; and set skip_next 1; and continue
      # git can only take a few options before a command, these are the ones mentioned in the "git" man page
      # e.g. `git --follow log` is wrong, `git --help log` is okay (and `git --help log $branch` is superfluous but works)
      # In case any other option is used before a command, we'll fail, but that's okay since it's invalid anyway
      switch $c
        # General options that can still take a command
        case "--help" "-p" "--paginate" "--no-pager" "--bare" "--no-replace-objects" --{literal,glob,noglob,icase}-pathspecs  --{exec-path,git-dir,work-tree,namespace}"=*"
          continue
        # General options with an argument we need to skip. The option=value versions have already been handled above
        case --{exec-path,git-dir,work-tree,namespace}
          set skip_next 0
          continue
        # General options that cause git to do something and exit - these behave like commands and everything after them is ignored
        case "--version" --{html,man,info}-path
          return 1
        # We assume that any other token that's not an argument to a general option is a command
        case "*"
          return 1
      end
    end
    return 0
  end
  return 1
end

function __fish_git_using_command
  set cmd (commandline -opc)
  if [ (count $cmd) -gt 1 ]
    if [ $argv[1] = $cmd[2] ]
      return 0
    end

    # aliased command
    set -l aliased (command git config --get "alias.$cmd[2]" ^ /dev/null | string split " ")
    if [ $argv[1] = "$aliased[1]" ]
      return 0
    end
  end
  return 1
end

function __fish_git_stash_using_command
  set cmd (commandline -opc)
  if [ (count $cmd) -gt 2 ]
    if [ $cmd[2] = 'stash' -a $argv[1] = $cmd[3] ]
      return 0
    end
  end
  return 1
end

function __fish_git_stash_not_using_subcommand
  set cmd (commandline -opc)
  if [ (count $cmd) -gt 2 -a $cmd[2] = 'stash' ]
    return 1
  end
  return 0
end

function __fish_git_complete_stashes
    set -l IFS ':'
    command git stash list --format=%gd:%gs ^/dev/null | while read -l name desc
        echo $name\t$desc
    end
end

function __fish_git_aliases
    set -l IFS \n
    command git config -z --get-regexp '^alias\.' ^/dev/null | while read -lz key value
        begin
            set -l IFS "."
            echo -n $key | read -l _ name
            printf "%s\t%s\n" $name "Alias for $value"
        end
    end
end

function __fish_git_custom_commands
    # complete all commands starting with git-
    # however, a few builtin commands are placed into $PATH by git because
    # they're used by the ssh transport. We could filter them out by checking
    # if any of these completion results match the name of the builtin git commands,
    # but it's simpler just to blacklist these names. They're unlikely to change,
    # and the failure mode is we accidentally complete a plumbing command.
  for name in (string replace -r "^.*/git-([^/]*)" '$1' $PATH/git-*)
        switch $name
            case cvsserver receive-pack shell upload-archive upload-pack
                # skip these
            case \*
                echo $name
        end
    end
end

# general options
complete -f -c git -n 'not __fish_git_needs_command' -l help -d 'Display the manual of a git command'

#### fetch
complete -f -c git -n '__fish_git_needs_command' -a fetch -d 'Download objects and refs from another repository'
complete -f -c git -n '__fish_git_using_command fetch' -a '(__fish_git_remotes)' -d 'Remote'
complete -f -c git -n '__fish_git_using_command fetch' -s q -l quiet -d 'Be quiet'
complete -f -c git -n '__fish_git_using_command fetch' -s v -l verbose -d 'Be verbose'
complete -f -c git -n '__fish_git_using_command fetch' -s a -l append -d 'Append ref names and object names'
# TODO --upload-pack
complete -f -c git -n '__fish_git_using_command fetch' -s f -l force -d 'Force update of local branches'
# TODO other options

#### filter-branch
complete -f -c git -n '__fish_git_needs_command' -a filter-branch -d 'Rewrite branches'
complete -f -c git -n '__fish_git_using_command filter-branch' -l env-filter -d 'This filter may be used if you only need to modify the environment'
complete -f -c git -n '__fish_git_using_command filter-branch' -l tree-filter -d 'This is the filter for rewriting the tree and its contents.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l index-filter -d 'This is the filter for rewriting the index.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l parent-filter -d 'This is the filter for rewriting the commit\\(cqs parent list.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l msg-filter -d 'This is the filter for rewriting the commit messages.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l commit-filter -d 'This is the filter for performing the commit.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l tag-name-filter -d 'This is the filter for rewriting tag names.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l subdirectory-filter -d 'Only look at the history which touches the given subdirectory.'
complete -f -c git -n '__fish_git_using_command filter-branch' -l prune-empty -d 'Ignore empty commits generated by filters'
complete -f -c git -n '__fish_git_using_command filter-branch' -l original -d 'Use this option to set the namespace where the original commits will be stored'
complete -r -c git -n '__fish_git_using_command filter-branch' -s d -d 'Use this option to set the path to the temporary directory used for rewriting'
complete -c git -n '__fish_git_using_command filter-branch' -s f -l force -d 'Force filter branch to start even w/ refs in refs/original or existing temp directory'

### remote
set -l remotecommands add rm show prune update rename set-head set-url set-branches
complete -f -c git -n '__fish_git_needs_command' -a remote -d 'Manage set of tracked repositories'
complete -f -c git -n '__fish_git_using_command remote' -a '(__fish_git_remotes)'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -s v -l verbose -d 'Be verbose'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a add -d 'Adds a new remote'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a rm -d 'Removes a remote'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a show -d 'Shows a remote'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a prune -d 'Deletes all stale tracking branches'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a update -d 'Fetches updates'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a rename -d 'Renames a remote'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a set-head -d 'Sets the default branch for a remote'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a set-url -d 'Changes URLs for a remote'
complete -f -c git -n "__fish_git_using_command remote; and not __fish_seen_subcommand_from $remotecommands" -a set-branches -d 'Changes the list of branches tracked by a remote'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from add " -s f -d 'Once the remote information is set up git fetch <name> is run'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from add " -l tags -d 'Import every tag from a remote with git fetch <name>'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from add " -l no-tags -d "Don't import tags from a remote with git fetch <name>"
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from set-branches" -l add -d 'Add to the list of currently tracked branches instead of replacing it'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from set-url" -l push -d 'Manipulate push URLs instead of fetch URLs'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from set-url" -l add -d 'Add new URL instead of changing the existing URLs'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from set-url" -l delete -d 'Remove URLs that match specified URL'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from show" -s n -d 'Remote heads are not queried, cached information is used instead'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from prune" -l dry-run -d 'Report what will be pruned but do not actually prune it'
complete -f -c git -n "__fish_git_using_command remote; and __fish_seen_subcommand_from update" -l prune -d 'Prune all remotes that are updated'

### show
complete -f -c git -n '__fish_git_needs_command' -a show -d 'Shows the last commit of a branch'
complete -f -c git -n '__fish_git_using_command show' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command show' -a '(__fish_git_unique_remote_branches)' -d 'Remote branch'
complete -f -c git -n '__fish_git_using_command show' -a '(__fish_git_commits)'
# TODO options

### show-branch
complete -f -c git -n '__fish_git_needs_command' -a show-branch -d 'Shows the commits on branches'
complete -f -c git -n '__fish_git_using_command show-branch' -a '(__fish_git_heads)' --description 'Branch'
# TODO options

### add
complete -c git -n '__fish_git_needs_command'    -a add -d 'Add file contents to the index'
complete -c git -n '__fish_git_using_command add' -s n -l dry-run -d "Don't actually add the file(s)"
complete -c git -n '__fish_git_using_command add' -s v -l verbose -d 'Be verbose'
complete -c git -n '__fish_git_using_command add' -s f -l force -d 'Allow adding otherwise ignored files'
complete -c git -n '__fish_git_using_command add' -s i -l interactive -d 'Interactive mode'
complete -c git -n '__fish_git_using_command add' -s p -l patch -d 'Interactively choose hunks to stage'
complete -c git -n '__fish_git_using_command add' -s e -l edit -d 'Manually create a patch'
complete -c git -n '__fish_git_using_command add' -s u -l update -d 'Only match tracked files'
complete -c git -n '__fish_git_using_command add' -s A -l all -d 'Match files both in working tree and index'
complete -c git -n '__fish_git_using_command add' -s N -l intent-to-add -d 'Record only the fact that the path will be added later'
complete -c git -n '__fish_git_using_command add' -l refresh -d "Don't add the file(s), but only refresh their stat"
complete -c git -n '__fish_git_using_command add' -l ignore-errors -d 'Ignore errors'
complete -c git -n '__fish_git_using_command add' -l ignore-missing -d 'Check if any of the given files would be ignored'
complete -f -c git -n '__fish_git_using_command add; and __fish_contains_opt -s p patch' -a '(__fish_git_modified_files)'
complete -f -c git -n '__fish_git_using_command add' -a '(__fish_git_add_files)'
# TODO options

### checkout
complete -f -c git -n '__fish_git_needs_command'    -a checkout -d 'Checkout and switch to a branch'
complete -f -c git -n '__fish_git_using_command checkout'  -a '(__fish_git_branches)' --description 'Branch'
complete -f -c git -n '__fish_git_using_command checkout'  -a '(__fish_git_unique_remote_branches)' --description 'Remote branch'
complete -f -c git -n '__fish_git_using_command checkout'  -a '(__fish_git_tags)' --description 'Tag'
complete -f -c git -n '__fish_git_using_command checkout' -a '(__fish_git_modified_files)' --description 'File'
complete -f -c git -n '__fish_git_using_command checkout' -s b -d 'Create a new branch'
complete -f -c git -n '__fish_git_using_command checkout' -s t -l track -d 'Track a new branch'
# TODO options

### apply
complete -f -c git -n '__fish_git_needs_command' -a apply -d 'Apply a patch on a git index file and a working tree'
# TODO options

### archive
complete -f -c git -n '__fish_git_needs_command' -a archive -d 'Create an archive of files from a named tree'
# TODO options

### bisect
complete -f -c git -n '__fish_git_needs_command' -a bisect -d 'Find the change that introduced a bug by binary search'
# TODO options

### branch
complete -f -c git -n '__fish_git_needs_command' -a branch -d 'List, create, or delete branches'
complete -f -c git -n '__fish_git_using_command branch' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command branch' -s d -d 'Delete branch'
complete -f -c git -n '__fish_git_using_command branch' -s D -d 'Force deletion of branch'
complete -f -c git -n '__fish_git_using_command branch' -s m -d 'Rename branch'
complete -f -c git -n '__fish_git_using_command branch' -s M -d 'Force renaming branch'
complete -f -c git -n '__fish_git_using_command branch' -s a -d 'Lists both local and remote branches'
complete -f -c git -n '__fish_git_using_command branch' -s t -l track -d 'Track remote branch'
complete -f -c git -n '__fish_git_using_command branch' -l no-track -d 'Do not track remote branch'
complete -f -c git -n '__fish_git_using_command branch' -l set-upstream -d 'Set remote branch to track'
complete -f -c git -n '__fish_git_using_command branch' -l merged -d 'List branches that have been merged'
complete -f -c git -n '__fish_git_using_command branch' -l no-merged -d 'List branches that have not been merged'

### cherry-pick
complete -f -c git -n '__fish_git_needs_command' -a cherry-pick -d 'Apply the change introduced by an existing commit'
complete -f -c git -n '__fish_git_using_command cherry-pick' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command cherry-pick' -a '(__fish_git_unique_remote_branches)' -d 'Remote branch'
complete -f -c git -n '__fish_git_using_command cherry-pick' -s e -l edit -d 'Edit the commit message prior to committing'
complete -f -c git -n '__fish_git_using_command cherry-pick' -s x -d 'Append info in generated commit on the origin of the cherry-picked change'
complete -f -c git -n '__fish_git_using_command cherry-pick' -s n -l no-commit -d 'Apply changes without making any commit'
complete -f -c git -n '__fish_git_using_command cherry-pick' -s s -l signoff -d 'Add Signed-off-by line to the commit message'
complete -f -c git -n '__fish_git_using_command cherry-pick' -l ff -d 'Fast-forward if possible'

### clone
complete -f -c git -n '__fish_git_needs_command' -a clone -d 'Clone a repository into a new directory'
complete -f -c git -n '__fish_git_using_command clone' -l no-hardlinks -d 'Copy files instead of using hardlinks'
complete -f -c git -n '__fish_git_using_command clone' -s q -l quiet  -d 'Operate quietly and do not report progress'
complete -f -c git -n '__fish_git_using_command clone' -s v -l verbose -d 'Provide more information on what is going on'
complete -f -c git -n '__fish_git_using_command clone' -s n -l no-checkout -d 'No checkout of HEAD is performed after the clone is complete'
complete -f -c git -n '__fish_git_using_command clone' -l bare -d 'Make a bare Git repository'
complete -f -c git -n '__fish_git_using_command clone' -l mirror -d 'Set up a mirror of the source repository'
complete -f -c git -n '__fish_git_using_command clone' -s o -l origin -d 'Use a specific name of the remote instead of the default'
complete -f -c git -n '__fish_git_using_command clone' -s b -l branch -d 'Use a specific branch instead of the one used by the cloned repository'
complete -f -c git -n '__fish_git_using_command clone' -l depth -d 'Truncate the history to a specified number of revisions'
complete -f -c git -n '__fish_git_using_command clone' -l recursive -d 'Initialize all submodules within the cloned repository'

### commit
complete -c git -n '__fish_git_needs_command'    -a commit -d 'Record changes to the repository'
complete -c git -n '__fish_git_using_command commit' -l amend -d 'Amend the log message of the last commit'
complete -f -c git -n '__fish_git_using_command commit' -a '(__fish_git_modified_files)'
# TODO options

### diff
complete -c git -n '__fish_git_needs_command'    -a diff -d 'Show changes between commits, commit and working tree, etc'
complete -c git -n '__fish_git_using_command diff' -a '(__fish_git_ranges)' -d 'Branch'
complete -c git -n '__fish_git_using_command diff' -l cached -d 'Show diff of changes in the index'
# TODO options

### difftool
complete -c git -n '__fish_git_needs_command'    -a difftool -d 'Open diffs in a visual tool'
complete -c git -n '__fish_git_using_command difftool' -a '(__fish_git_ranges)' -d 'Branch'
complete -c git -n '__fish_git_using_command difftool' -l cached -d 'Visually show diff of changes in the index'
# TODO options


### grep
complete -c git -n '__fish_git_needs_command'    -a grep -d 'Print lines matching a pattern'
# TODO options

### init
complete -f -c git -n '__fish_git_needs_command' -a init -d 'Create an empty git repository or reinitialize an existing one'
# TODO options

### log
complete -c git -n '__fish_git_needs_command'    -a log -d 'Show commit logs'
complete -c git -n '__fish_git_using_command log' -a '(__fish_git_heads) (__fish_git_ranges)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command log' -l pretty -a 'oneline short medium full fuller email raw format:'
# TODO options

### merge
complete -f -c git -n '__fish_git_needs_command' -a merge -d 'Join two or more development histories together'
complete -f -c git -n '__fish_git_using_command merge' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command merge' -a '(__fish_git_unique_remote_branches)' -d 'Remote branch'
complete -f -c git -n '__fish_git_using_command merge' -l commit -d "Autocommit the merge"
complete -f -c git -n '__fish_git_using_command merge' -l no-commit -d "Don't autocommit the merge"
complete -f -c git -n '__fish_git_using_command merge' -l edit -d 'Edit auto-generated merge message'
complete -f -c git -n '__fish_git_using_command merge' -l no-edit -d "Don't edit auto-generated merge message"
complete -f -c git -n '__fish_git_using_command merge' -l ff -d "Don't generate a merge commit if merge is fast-forward"
complete -f -c git -n '__fish_git_using_command merge' -l no-ff -d "Generate a merge commit even if merge is fast-forward"
complete -f -c git -n '__fish_git_using_command merge' -l ff-only -d 'Refuse to merge unless fast-forward possible'
complete -f -c git -n '__fish_git_using_command merge' -l log -d 'Populate the log message with one-line descriptions'
complete -f -c git -n '__fish_git_using_command merge' -l no-log -d "Don't populate the log message with one-line descriptions"
complete -f -c git -n '__fish_git_using_command merge' -l stat -d "Show diffstat of the merge"
complete -f -c git -n '__fish_git_using_command merge' -s n -l no-stat -d "Don't show diffstat of the merge"
complete -f -c git -n '__fish_git_using_command merge' -l squash -d "Squash changes from other branch as a single commit"
complete -f -c git -n '__fish_git_using_command merge' -l no-squash -d "Don't squash changes"
complete -f -c git -n '__fish_git_using_command merge' -s q -l quiet -d 'Be quiet'
complete -f -c git -n '__fish_git_using_command merge' -s v -l verbose -d 'Be verbose'
complete -f -c git -n '__fish_git_using_command merge' -l progress -d 'Force progress status'
complete -f -c git -n '__fish_git_using_command merge' -l no-progress -d 'Force no progress status'
complete -f -c git -n '__fish_git_using_command merge' -s m -d 'Set the commit message'
complete -f -c git -n '__fish_git_using_command merge' -l abort -d 'Abort the current conflict resolution process'

# TODO options

### mv
complete -c git -n '__fish_git_needs_command'    -a mv -d 'Move or rename a file, a directory, or a symlink'
# TODO options

### prune
complete -f -c git -n '__fish_git_needs_command' -a prune -d 'Prune all unreachable objects from the object database'
# TODO options

### pull
complete -f -c git -n '__fish_git_needs_command' -a pull -d 'Fetch from and merge with another repository or a local branch'
complete -f -c git -n '__fish_git_using_command pull' -s q -l quiet -d 'Be quiet'
complete -f -c git -n '__fish_git_using_command pull' -s v -l verbose -d 'Be verbose'
# Options related to fetching
complete -f -c git -n '__fish_git_using_command pull' -l all -d 'Fetch all remotes'
complete -f -c git -n '__fish_git_using_command pull' -s a -l append -d 'Append ref names and object names'
complete -f -c git -n '__fish_git_using_command pull' -s f -l force -d 'Force update of local branches'
complete -f -c git -n '__fish_git_using_command pull' -s k -l keep -d 'Keep downloaded pack'
complete -f -c git -n '__fish_git_using_command pull' -l no-tags -d 'Disable automatic tag following'
# TODO --upload-pack
complete -f -c git -n '__fish_git_using_command pull' -l progress -d 'Force progress status'
complete -f -c git -n '__fish_git_using_command pull' -a '(git remote)' -d 'Remote alias'
complete -f -c git -n '__fish_git_using_command pull' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command pull' -a '(__fish_git_unique_remote_branches)' -d 'Remote branch'
# TODO other options

### push
complete -f -c git -n '__fish_git_needs_command' -a push -d 'Update remote refs along with associated objects'
complete -f -c git -n '__fish_git_using_command push' -a '(git remote)' -d 'Remote alias'
complete -f -c git -n '__fish_git_using_command push' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command push' -l all -d 'Push all refs under refs/heads/'
complete -f -c git -n '__fish_git_using_command push' -l prune -d "Remove remote branches that don't have a local counterpart"
complete -f -c git -n '__fish_git_using_command push' -l mirror -d 'Push all refs under refs/'
complete -f -c git -n '__fish_git_using_command push' -l delete -d 'Delete all listed refs from the remote repository'
complete -f -c git -n '__fish_git_using_command push' -l tags -d 'Push all refs under refs/tags'
complete -f -c git -n '__fish_git_using_command push' -s n -l dry-run -d 'Do everything except actually send the updates'
complete -f -c git -n '__fish_git_using_command push' -l porcelain -d 'Produce machine-readable output'
complete -f -c git -n '__fish_git_using_command push' -s f -l force -d 'Force update of remote refs'
complete -f -c git -n '__fish_git_using_command push' -s u -l set-upstream -d 'Add upstream (tracking) reference'
complete -f -c git -n '__fish_git_using_command push' -s q -l quiet -d 'Be quiet'
complete -f -c git -n '__fish_git_using_command push' -s v -l verbose -d 'Be verbose'
complete -f -c git -n '__fish_git_using_command push' -l progress -d 'Force progress status'
# TODO --recurse-submodules=check|on-demand

### rebase
complete -f -c git -n '__fish_git_needs_command' -a rebase -d 'Forward-port local commits to the updated upstream head'
complete -f -c git -n '__fish_git_using_command rebase' -a '(git remote)' -d 'Remote alias'
complete -f -c git -n '__fish_git_using_command rebase' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command rebase' -l continue -d 'Restart the rebasing process'
complete -f -c git -n '__fish_git_using_command rebase' -l abort -d 'Abort the rebase operation'
complete -f -c git -n '__fish_git_using_command rebase' -l keep-empty -d "Keep the commits that don't cahnge anything"
complete -f -c git -n '__fish_git_using_command rebase' -l skip -d 'Restart the rebasing process by skipping the current patch'
complete -f -c git -n '__fish_git_using_command rebase' -s m -l merge -d 'Use merging strategies to rebase'
complete -f -c git -n '__fish_git_using_command rebase' -s q -l quiet -d 'Be quiet'
complete -f -c git -n '__fish_git_using_command rebase' -s v -l verbose -d 'Be verbose'
complete -f -c git -n '__fish_git_using_command rebase' -l stat -d "Show diffstat of the rebase"
complete -f -c git -n '__fish_git_using_command rebase' -s n -l no-stat -d "Don't show diffstat of the rebase"
complete -f -c git -n '__fish_git_using_command rebase' -l verify -d "Allow the pre-rebase hook to run"
complete -f -c git -n '__fish_git_using_command rebase' -l no-verify -d "Don't allow the pre-rebase hook to run"
complete -f -c git -n '__fish_git_using_command rebase' -s f -l force-rebase -d 'Force the rebase'
complete -f -c git -n '__fish_git_using_command rebase' -s i -l interactive -d 'Interactive mode'
complete -f -c git -n '__fish_git_using_command rebase' -s p -l preserve-merges -d 'Try to recreate merges'
complete -f -c git -n '__fish_git_using_command rebase' -l root -d 'Rebase all reachable commits'
complete -f -c git -n '__fish_git_using_command rebase' -l autosquash -d 'Automatic squashing'
complete -f -c git -n '__fish_git_using_command rebase' -l no-autosquash -d 'No automatic squashing'
complete -f -c git -n '__fish_git_using_command rebase' -l no-ff -d 'No fast-forward'

### reset
complete -c git -n '__fish_git_needs_command'    -a reset -d 'Reset current HEAD to the specified state'
complete -f -c git -n '__fish_git_using_command reset' -l hard -d 'Reset files in working directory'
complete -c git -n '__fish_git_using_command reset' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command reset' -a '(__fish_git_staged_files)' -d 'File'
# TODO options

### revert
complete -f -c git -n '__fish_git_needs_command' -a revert -d 'Revert an existing commit'
# TODO options

### rm
complete -c git -n '__fish_git_needs_command'    -a rm     -d 'Remove files from the working tree and from the index'
complete -c git -n '__fish_git_using_command rm' -f
complete -c git -n '__fish_git_using_command rm' -l cached -d 'Keep local copies'
complete -c git -n '__fish_git_using_command rm' -l ignore-unmatch -d 'Exit with a zero status even if no files matched'
complete -c git -n '__fish_git_using_command rm' -s r -d 'Allow recursive removal'
complete -c git -n '__fish_git_using_command rm' -s q -l quiet -d 'Be quiet'
complete -c git -n '__fish_git_using_command rm' -s f -l force -d 'Override the up-to-date check'
complete -c git -n '__fish_git_using_command rm' -s n -l dry-run -d 'Dry run'
# TODO options

### status
complete -f -c git -n '__fish_git_needs_command' -a status -d 'Show the working tree status'
complete -f -c git -n '__fish_git_using_command status' -s s -l short -d 'Give the output in the short-format'
complete -f -c git -n '__fish_git_using_command status' -s b -l branch -d 'Show the branch and tracking info even in short-format'
complete -f -c git -n '__fish_git_using_command status'      -l porcelain -d 'Give the output in a stable, easy-to-parse format'
complete -f -c git -n '__fish_git_using_command status' -s z -d 'Terminate entries with null character'
complete -f -c git -n '__fish_git_using_command status' -s u -l untracked-files -x -a 'no normal all' -d 'The untracked files handling mode'
complete -f -c git -n '__fish_git_using_command status' -l ignore-submodules -x -a 'none untracked dirty all' -d 'Ignore changes to submodules'
# TODO options

### tag
complete -f -c git -n '__fish_git_needs_command' -a tag -d 'Create, list, delete or verify a tag object signed with GPG'
complete -f -c git -n '__fish_git_using_command tag; and __fish_not_contain_opt -s d; and __fish_not_contain_opt -s v; and test (count (commandline -opc | __fish_sgrep -v -e \'^-\')) -eq 3' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command tag' -s a -l annotate -d 'Make an unsigned, annotated tag object'
complete -f -c git -n '__fish_git_using_command tag' -s s -l sign -d 'Make a GPG-signed tag'
complete -f -c git -n '__fish_git_using_command tag' -s d -l delete -d 'Remove a tag'
complete -f -c git -n '__fish_git_using_command tag' -s v -l verify -d 'Verify signature of a tag'
complete -f -c git -n '__fish_git_using_command tag' -s f -l force -d 'Force overwriting exising tag'
complete -f -c git -n '__fish_git_using_command tag' -s l -l list -d 'List tags'
complete -f -c git -n '__fish_git_using_command tag; and __fish_contains_opt -s d' -a '(__fish_git_tags)' -d 'Tag'
complete -f -c git -n '__fish_git_using_command tag; and __fish_contains_opt -s v' -a '(__fish_git_tags)' -d 'Tag'
# TODO options

### stash
complete -c git -n '__fish_git_needs_command' -a stash -d 'Stash away changes'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a list -d 'List stashes'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a show -d 'Show the changes recorded in the stash'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a pop -d 'Apply and remove a single stashed state'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a apply -d 'Apply a single stashed state'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a clear -d 'Remove all stashed states'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a drop -d 'Remove a single stashed state from the stash list'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a create -d 'Create a stash'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a save -d 'Save a new stash'
complete -f -c git -n '__fish_git_using_command stash; and __fish_git_stash_not_using_subcommand' -a branch -d 'Create a new branch from a stash'

complete -f -c git -n '__fish_git_stash_using_command apply' -a '(__fish_git_complete_stashes)'
complete -f -c git -n '__fish_git_stash_using_command branch' -a '(__fish_git_complete_stashes)'
complete -f -c git -n '__fish_git_stash_using_command drop' -a '(__fish_git_complete_stashes)'
complete -f -c git -n '__fish_git_stash_using_command pop' -a '(__fish_git_complete_stashes)'
complete -f -c git -n '__fish_git_stash_using_command show' -a '(__fish_git_complete_stashes)'

### config
complete -f -c git -n '__fish_git_needs_command' -a config -d 'Set and read git configuration variables'
# TODO options

### format-patch
complete -f -c git -n '__fish_git_needs_command' -a format-patch -d 'Generate patch series to send upstream'
complete -f -c git -n '__fish_git_using_command format-patch' -a '(__fish_git_branches)' -d 'Branch'
complete -f -c git -n '__fish_git_using_command format-patch' -s p -l no-stat -d "Generate plain patches without diffstat"
complete -f -c git -n '__fish_git_using_command format-patch' -s s -l no-patch -d "Suppress diff output"
complete -f -c git -n '__fish_git_using_command format-patch' -l minimal -d "Spend more time to create smaller diffs"
complete -f -c git -n '__fish_git_using_command format-patch' -l patience -d "Generate diff with the 'patience' algorithm"
complete -f -c git -n '__fish_git_using_command format-patch' -l histogram -d "Generate diff with the 'histogram' algorithm"
complete -f -c git -n '__fish_git_using_command format-patch' -l stdout -d "Print all commits to stdout in mbox format"
complete -f -c git -n '__fish_git_using_command format-patch' -l numstat -d "Show number of added/deleted lines in decimal notation"
complete -f -c git -n '__fish_git_using_command format-patch' -l shortstat -d "Output only last line of the stat"
complete -f -c git -n '__fish_git_using_command format-patch' -l summary -d "Output a condensed summary of extended header information"
complete -f -c git -n '__fish_git_using_command format-patch' -l no-renames -d "Disable rename detection"
complete -f -c git -n '__fish_git_using_command format-patch' -l full-index -d "Show full blob object names"
complete -f -c git -n '__fish_git_using_command format-patch' -l binary -d "Output a binary diff for use with git apply"
complete -f -c git -n '__fish_git_using_command format-patch' -l find-copies-harder -d "Also inspect unmodified files as source for a copy"
complete -f -c git -n '__fish_git_using_command format-patch' -l text -s a -d "Treat all files as text"
complete -f -c git -n '__fish_git_using_command format-patch' -l ignore-space-at-eol -d "Ignore changes in whitespace at EOL"
complete -f -c git -n '__fish_git_using_command format-patch' -l ignore-space-change -s b -d "Ignore changes in amount of whitespace"
complete -f -c git -n '__fish_git_using_command format-patch' -l ignore-all-space -s w -d "Ignore whitespace when comparing lines"
complete -f -c git -n '__fish_git_using_command format-patch' -l ignore-blank-lines -d "Ignore changes whose lines are all blank"
complete -f -c git -n '__fish_git_using_command format-patch' -l function-context -s W -d "Show whole surrounding functions of changes"
complete -f -c git -n '__fish_git_using_command format-patch' -l ext-diff -d "Allow an external diff helper to be executed"
complete -f -c git -n '__fish_git_using_command format-patch' -l no-ext-diff -d "Disallow external diff helpers"
complete -f -c git -n '__fish_git_using_command format-patch' -l no-textconv -d "Disallow external text conversion filters for binary files (Default)"
complete -f -c git -n '__fish_git_using_command format-patch' -l textconv -d "Allow external text conversion filters for binary files (Resulting diff is unappliable)"
complete -f -c git -n '__fish_git_using_command format-patch' -l no-prefix -d "Do not show source or destination prefix"
complete -f -c git -n '__fish_git_using_command format-patch' -l numbered -s n -d "Name output in [Patch n/m] format, even with a single patch"
complete -f -c git -n '__fish_git_using_command format-patch' -l no-numbered -s N -d "Name output in [Patch] format, even with multiple patches"


## git submodule
set -l submodulecommands add status init update summary foreach sync
complete -f -c git -n '__fish_git_needs_command' -a submodule -d 'Initialize, update or inspect submodules'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'add' -d 'Add a submodule'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'status' -d 'Show submodule status'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'init' -d 'Initialize all submodules'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'update' -d 'Update all submodules'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'summary' -d 'Show commit summary'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'foreach' -d 'Run command on each submodule'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -a 'sync' -d 'Sync submodules\' URL with .gitmodules'
complete -f -c git -n "__fish_git_using_command submodule; and not __fish_seen_subcommand_from $submodulecommands" -s q -l quiet -d "Only print error messages"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -l init -d "Initialize all submodules"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -l checkout -d "Checkout the superproject's commit on a detached HEAD in the submodule"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -l merge -d "Merge the superproject's commit into the current branch of the submodule"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -l rebase -d "Rebase current branch onto the superproject's commit"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -s N -l no-fetch -d "Don't fetch new objects from the remote"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -l remote -d "Instead of using superproject's SHA-1, use the state of the submodule's remote-tracking branch"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from update' -l force -d "Throw away local changes when switching to a different commit and always run checkout"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from add' -l force -d "Also add ignored submodule path"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from deinit' -l force -d "Remove even with local changes"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from status summary' -l cached -d "Use the commit stored in the index"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from summary' -l files -d "Compare the commit in the index with submodule HEAD"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from foreach update status' -l recursive -d "Traverse submodules recursively"
complete -f -c git -n '__fish_git_using_command submodule; and __fish_seen_subcommand_from foreach' -a "(__fish_complete_subcommand --fcs-skip=3)"

## git whatchanged
complete -f -c git -n '__fish_git_needs_command' -a whatchanged -d 'Show logs with difference each commit introduces'

## Aliases (custom user-defined commands)
complete -c git -n '__fish_git_needs_command' -a '(__fish_git_aliases)'

### git clean
complete -f -c git -n '__fish_git_needs_command' -a clean -d 'Remove untracked files from the working tree'
complete -f -c git -n '__fish_git_using_command clean' -s f -l force -d 'Force run'
complete -f -c git -n '__fish_git_using_command clean' -s i -l interactive -d 'Show what would be done and clean files interactively'
complete -f -c git -n '__fish_git_using_command clean' -s n -l dry-run -d 'Don\'t actually remove anything, just show what would be done'
complete -f -c git -n '__fish_git_using_command clean' -s q -l quite -d 'Be quiet, only report errors'
complete -f -c git -n '__fish_git_using_command clean' -s d -d 'Remove untracked directories in addition to untracked files'
complete -f -c git -n '__fish_git_using_command clean' -s x -d 'Remove ignored files, as well'
complete -f -c git -n '__fish_git_using_command clean' -s X -d 'Remove only ignored files'
# TODO -e option

## Custom commands (git-* commands installed in the PATH)
complete -c git -n '__fish_git_needs_command' -a '(__fish_git_custom_commands)' -d 'Custom command'






## Vagrant completion 
# vagrant autocompletion

function __fish_vagrant_no_command --description 'Test if vagrant has yet to be given the main command'
  set -l cmd (commandline -opc)
  test (count $cmd) -eq 1
end

function __fish_vagrant_using_command
  set -l cmd (commandline -opc)
  set -q cmd[2]; and test "$argv[1]" = $cmd[2]
end

function __fish_vagrant_using_command_and_no_subcommand
  set -l cmd (commandline -opc)
  test (count $cmd) -eq 2; and test "$argv[1]" = "$cmd[2]"
end

function __fish_vagrant_using_subcommand --argument-names cmd_main cmd_sub
    set -l cmd (commandline -opc)
    set -q cmd[3]; and test "$cmd_main" = $cmd[2] -a "$cmd_sub" = $cmd[3]
end

function __fish_vagrant_boxes --description 'Lists all available Vagrant boxes'
  set -l IFS \n\ \t
  command vagrant box list | while read -l name _
    echo $name
  end
end

# --version and --help are always active
complete -c vagrant -f -s v -l version -d 'Print the version and exit'
complete -c vagrant -f -s h -l help -d 'Print the help and exit'

# box
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'box' -d 'Manages boxes'
complete -c vagrant -n '__fish_vagrant_using_command_and_no_subcommand box' -a add -d 'Adds a box'
complete -c vagrant -f -n '__fish_vagrant_using_command_and_no_subcommand box' -a list -d 'Lists all the installed boxes'
complete -c vagrant -f -n '__fish_vagrant_using_command_and_no_subcommand box' -a remove -d 'Removes a box from Vagrant'
complete -c vagrant -f -n '__fish_vagrant_using_command_and_no_subcommand box' -a repackage -d 'Repackages the given box for redistribution'
complete -c vagrant -f -n '__fish_vagrant_using_subcommand box add' -l provider -d 'Verifies the box with the given provider'
complete -c vagrant -f -n '__fish_vagrant_using_subcommand box remove' -a '(__fish_vagrant_boxes)'

# connect
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'connect' -d 'Connect to a remotely shared Vagrant environment'
complete -c vagrant -f -n '__fish_vagrant_using_command connect' -l disable-static-ip -d 'No static IP, only a SOCKS proxy'
complete -c vagrant -f -n '__fish_vagrant_using_command connect' -l static-ip -r -d 'Manually override static IP chosen'
complete -c vagrant -f -n '__fish_vagrant_using_command connect' -l ssh -d 'SSH into the remote machine'


# destroy
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'destroy' -d 'Destroys the running machine'
complete -c vagrant -f -n '__fish_vagrant_using_command destroy' -s f -l force -d 'Destroy without confirmation'

# global-status
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'global-status' -d 'Global status of Vagrant environments'
complete -c vagrant -f -n '__fish_vagrant_using_command global-status' -l prune -d 'Prune invalid entries'

# gem
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'gem' -d 'Install Vagrant plugins through ruby gems'

# halt
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'halt' -d 'Shuts down the running machine'
complete -c vagrant -f -n '__fish_vagrant_using_command halt' -s f -l force -d 'Force shut down'

# init
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'init' -d 'Initializes the Vagrant environment'
complete -c vagrant -f -n '__fish_vagrant_using_command init' -a '(__fish_vagrant_boxes)'

# login
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'login' -d 'Log in to Vagrant Cloud'
complete -c vagrant -f -n '__fish_vagrant_using_command login ' -s c -l check -d "Only checks if you're logged in"
complete -c vagrant -f -n '__fish_vagrant_using_command login ' -s k -l logout -d "Logs you out if you're logged in"

# package
complete -c vagrant -n '__fish_vagrant_no_command' -a 'package' -d 'Packages a running machine into a reusable box'
complete -c vagrant -n '__fish_vagrant_using_command package' -l base -d 'Name or UUID of the virtual machine'
complete -c vagrant -n '__fish_vagrant_using_command package' -l output -d 'Output file name'
complete -c vagrant -n '__fish_vagrant_using_command package' -l include -r -d 'Additional files to package with the box'
complete -c vagrant -n '__fish_vagrant_using_command package' -l vagrantfile -r -d 'Include the given Vagrantfile with the box'

# plugin
complete -c vagrant -n '__fish_vagrant_no_command' -a 'plugin' -d 'Manages plugins'
complete -c vagrant -n '__fish_vagrant_using_command plugin' -a install -r -d 'Installs a plugin'
complete -c vagrant -n '__fish_vagrant_using_command plugin' -a license -r -d 'Installs a license for a proprietary Vagrant plugin'
complete -c vagrant -f -n '__fish_vagrant_using_command plugin' -a list -d 'Lists installed plugins'
complete -c vagrant -n '__fish_vagrant_using_command plugin' -a uninstall -r -d 'Uninstall the given plugin'

# provision
complete -c vagrant -n '__fish_vagrant_no_command' -a 'provision' -d 'Runs configured provisioners on the running machine'
complete -c vagrant -n '__fish_vagrant_using_command provision' -l provision-with -r -d 'Run only the given provisioners'

# rdp
complete -c vagrant -n '__fish_vagrant_no_command' -a 'rdp' -d 'Connects to machine via RDP'

# reload
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'reload' -d 'Restarts the running machine'
complete -c vagrant -f -n '__fish_vagrant_using_command reload' -l no-provision -r -d 'Provisioners will not run'
complete -c vagrant -f -n '__fish_vagrant_using_command reload' -l provision-with -r -d 'Run only the given provisioners'

# resume
complete -c vagrant -x -n '__fish_vagrant_no_command' -a 'resume' -d 'Resumes a previously suspended machine'

# share
complete -c vagrant -n '__fish_vagrant_no_command' -a 'share' -d 'Share your Vagrant environment with anyone in the world'
complete -c vagrant -n '__fish_vagrant_using_command share' -l disable-http -d 'Disable publicly visible HTTP endpoint'
complete -c vagrant -n '__fish_vagrant_using_command share' -l domain -r -d 'Domain the share name will be a subdomain of'
complete -c vagrant -n '__fish_vagrant_using_command share' -l http -r -d 'Local HTTP port to forward to'
complete -c vagrant -n '__fish_vagrant_using_command share' -l https -r -d 'Local HTTPS port to forward to'
complete -c vagrant -n '__fish_vagrant_using_command share' -l name -r -d 'Specific name for the share'
complete -c vagrant -n '__fish_vagrant_using_command share' -l ssh -d "Allow 'vagrant connect --ssh' access"
complete -c vagrant -n '__fish_vagrant_using_command share' -l ssh-no-password -d "Key won't be encrypted with --ssh"
complete -c vagrant -n '__fish_vagrant_using_command share' -l ssh-port -r -d 'Specific port for SSH when using --ssh'
complete -c vagrant -n '__fish_vagrant_using_command share' -l ssh-once -d "Allow 'vagrant connect --ssh' only one time"

# ssh
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'ssh' -d 'SSH into a running machine'
complete -c vagrant -f -n '__fish_vagrant_using_command ssh' -s c -l command -r -d 'Executes a single SSH command'
complete -c vagrant -f -n '__fish_vagrant_using_command ssh' -s p -l plain -r -d 'Does not authenticate'

# ssh-config
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'ssh-config' -d 'Outputs configuration for an SSH config file'
complete -c vagrant -f -n '__fish_vagrant_using_command ssh-config' -l host -r -d 'Name of the host for the outputted configuration'

# status
complete -c vagrant -x -n '__fish_vagrant_no_command' -a 'status' -d 'Status of the machines Vagrant is managing'

# suspend
complete -c vagrant -x -n '__fish_vagrant_no_command' -a 'suspend' -d 'Suspends the running machine'

# up
complete -c vagrant -f -n '__fish_vagrant_no_command' -a 'up' -d 'Creates and configures guest machines'
complete -c vagrant -f -n '__fish_vagrant_using_command up' -l provision -d 'Enable provision'
complete -c vagrant -f -n '__fish_vagrant_using_command up' -l no-provision -d 'Disable provision'
complete -c vagrant -f -n '__fish_vagrant_using_command up' -l provision-with -r -d 'Enable only certain provisioners, by type'



## NPM completion
# NPM (https://npmjs.org) completions for Fish shell
# __fish_npm_needs_* and __fish_npm_using_* taken from:
# https://stackoverflow.com/questions/16657803/creating-autocomplete-script-with-sub-commands
# see also Fish's large set of completions for examples:
# https://github.com/fish-shell/fish-shell/tree/master/share/completions

function __fish_npm_needs_command
  set cmd (commandline -opc)

  if [ (count $cmd) -eq 1 ]
    return 0
  end

  return 1
end

function __fish_npm_using_command
  set cmd (commandline -opc)

  if [ (count $cmd) -gt 1 ]
    if [ $argv[1] = $cmd[2] ]
      return 0
    end
  end

  return 1
end

function __fish_npm_needs_option
  switch (commandline -ct)
    case "-*"
      return 0
  end
  return 1
end

function __fish_complete_npm --description "Complete the commandline using npm's 'completion' tool"
  # npm completion is bash-centric, so we need to translate fish's "commandline" stuff to bash's $COMP_* stuff
  # COMP_LINE is an array with the words in the commandline
  set -lx COMP_LINE (commandline -o)
  # COMP_CWORD is the index of the current word in COMP_LINE
  # bash starts arrays with 0, so subtract 1
  set -lx COMP_CWORD (math (count $COMP_LINE) - 1)
  # COMP_POINT is the index of point/cursor when the commandline is viewed as a string
  set -lx COMP_POINT (commandline -C)
  # If the cursor is after the last word, the empty token will disappear in the expansion
  # Readd it
  if test (commandline -ct) = ""
    set COMP_CWORD (math $COMP_CWORD + 1)
    set COMP_LINE $COMP_LINE ""
  end
  npm completion -- $COMP_LINE ^/dev/null
end

# use npm completion for most of the things,
# except options completion because it sucks at it.
# see: https://github.com/npm/npm/issues/9524
# and: https://github.com/fish-shell/fish-shell/pull/2366
complete -f -c npm -n 'not __fish_npm_needs_option' -a "(__fish_complete_npm)"

# list available npm scripts and their parial content
function __fish_npm_run
  command npm run | command grep -v '^[^ ]' | command grep -v '^$' | command sed "s/^ *//" | while read -l name
    set -l trim 20
    read -l value
    echo "$value" | cut -c1-$trim | read -l value
    printf "%s\t%s\n" $name $value
  end
end

# run
for c in run run-script
    complete -f -c npm -n "__fish_npm_using_command $c" -a "(__fish_npm_run)"
end

# cache
complete -f -c npm -n '__fish_npm_needs_command' -a 'cache' -d "Manipulates package's cache"
complete -f -c npm -n '__fish_npm_using_command cache' -a 'add' -d 'Add the specified package to the local cache'
complete -f -c npm -n '__fish_npm_using_command cache' -a 'clean' -d 'Delete  data  out of the cache folder'
complete -f -c npm -n '__fish_npm_using_command cache' -a 'ls' -d 'Show the data in the cache'

# config
for c in 'c' 'config'
  complete -f -c npm -n "__fish_npm_needs_command" -a "$c" -d 'Manage the npm configuration files'
  complete -f -c npm -n "__fish_npm_using_command $c" -a 'set' -d 'Sets the config key to the value'
  complete -f -c npm -n "__fish_npm_using_command $c" -a 'get' -d 'Echo the config value to stdout'
  complete -f -c npm -n "__fish_npm_using_command $c" -a 'delete' -d 'Deletes the key from all configuration files'
  complete -f -c npm -n "__fish_npm_using_command $c" -a 'list' -d 'Show all the config settings'
  complete -f -c npm -n "__fish_npm_using_command $c" -a 'ls' -d 'Show all the config settings'
  complete -f -c npm -n "__fish_npm_using_command $c" -a 'edit' -d 'Opens the config file in an editor'
end
# get, set also exist as shorthands
complete -f -c npm -n "__fish_npm_needs_command" -a 'get' -d 'Echo the config value to stdout'
complete -f -c npm -n "__fish_npm_needs_command" -a 'set' -d 'Sets the config key to the value'

# install
for c in 'install' 'isntall' 'i'
    complete -f -c npm -n '__fish_npm_needs_command' -a "$c" -d 'install a package'
    complete -f -c npm -n "__fish_npm_using_command $c" -l save-dev -d 'Save to devDependencies in package.json'
    complete -f -c npm -n "__fish_npm_using_command $c" -l save -d 'Save to dependencies in package.json'
    complete -f -c npm -n "__fish_npm_using_command $c" -s g -l global -d 'Install package globally'
end

# list
for c in 'la' 'list' 'll' 'ls'
  complete -f -c npm -n '__fish_npm_needs_command' -a "$c" -d 'List installed packages'
  complete -f -c npm -n "__fish_npm_using_command $c" -s g -l global -d 'List packages in the global install prefix instead of in the current project'
  complete -f -c npm -n "__fish_npm_using_command $c" -l json -d 'Show information in JSON format'
  complete -f -c npm -n "__fish_npm_using_command $c" -l long -d 'Show extended information'
  complete -f -c npm -n "__fish_npm_using_command $c" -l parseable -d 'Show parseable output instead of tree view'
  complete -x -c npm -n "__fish_npm_using_command $c" -l depth -d 'Max display depth of the dependency tree'
end

# owner
complete -f -c npm -n '__fish_npm_needs_command' -a 'owner' -d 'Manage package owners'
complete -f -c npm -n '__fish_npm_using_command owner' -a 'ls' -d 'List package owners'
complete -f -c npm -n '__fish_npm_using_command owner' -a 'add' -d 'Add a new owner to package'
complete -f -c npm -n '__fish_npm_using_command owner' -a 'rm' -d 'Remove an owner from package'

# remove
for c in 'r' 'remove' 'rm' 'un' 'uninstall' 'unlink'
    complete -f -c npm -n '__fish_npm_needs_command' -a "$c" -d 'remove package'
    complete -x -c npm -n "__fish_npm_using_command $c" -s g -l global -d 'remove global package'
    complete -x -c npm -n "__fish_npm_using_command $c" -l save -d 'Package will be removed from your dependencies'
    complete -x -c npm -n "__fish_npm_using_command $c" -l save-dev -d 'Package will be removed from your devDependencies'
    complete -x -c npm -n "__fish_npm_using_command $c" -l save-optional -d 'Package will be removed from your optionalDependencies'
end

# search
for c in 'find' 's' 'se' 'search'
    complete -f -c npm -n '__fish_npm_needs_command' -a "$c" -d 'Search for packages'
    complete -x -c npm -n "__fish_npm_using_command $c" -l long -d 'Display full package descriptions and other long text across multiple lines'
end

# update
for c in 'up' 'update'
    complete -f -c npm -n '__fish_npm_needs_command' -a "$c" -d 'Update package(s)'
    complete -f -c npm -n "__fish_npm_using_command $c" -s g -l global -d 'Update global package(s)'
end

# misc shorter explanations
complete -f -c npm -n '__fish_npm_needs_command' -a 'adduser add-user login' -d 'Add a registry user account'
complete -f -c npm -n '__fish_npm_needs_command' -a 'bin' -d 'Display npm bin folder'
complete -f -c npm -n '__fish_npm_needs_command' -a 'bugs issues' -d 'Bugs for a package in a web browser maybe'
complete -f -c npm -n '__fish_npm_needs_command' -a 'ddp dedupe find-dupes' -d 'Reduce duplication'
complete -f -c npm -n '__fish_npm_needs_command' -a 'deprecate' -d 'Deprecate a version of a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'docs home' -d 'Docs for a package in a web browser maybe'
complete -f -c npm -n '__fish_npm_needs_command' -a 'edit' -d 'Edit an installed package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'explore' -d 'Browse an installed package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'faq' -d 'Frequently Asked Questions'
complete -f -c npm -n '__fish_npm_needs_command' -a 'help-search' -d 'Search npm help documentation'
complete -f -c npm -n '__fish_npm_using_command help-search' -l long -d 'Display full package descriptions and other long text across multiple lines'
complete -f -c npm -n '__fish_npm_needs_command' -a 'info v view' -d 'View registry info'
complete -f -c npm -n '__fish_npm_needs_command' -a 'link ln' -d 'Symlink a package folder'
complete -f -c npm -n '__fish_npm_needs_command' -a 'outdated' -d 'Check for outdated packages'
complete -f -c npm -n '__fish_npm_needs_command' -a 'pack' -d 'Create a tarball from a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'prefix' -d 'Display NPM prefix'
complete -f -c npm -n '__fish_npm_needs_command' -a 'prune' -d 'Remove extraneous packages'
complete -c npm -n '__fish_npm_needs_command' -a 'publish' -d 'Publish a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'rb rebuild' -d 'Rebuild a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'root ' -d 'Display npm root'
complete -f -c npm -n '__fish_npm_needs_command' -a 'run-script run' -d 'Run arbitrary package scripts'
complete -f -c npm -n '__fish_npm_needs_command' -a 'shrinkwrap' -d 'Lock down dependency versions'
complete -f -c npm -n '__fish_npm_needs_command' -a 'star' -d 'Mark your favorite packages'
complete -f -c npm -n '__fish_npm_needs_command' -a 'stars' -d 'View packages marked as favorites'
complete -f -c npm -n '__fish_npm_needs_command' -a 'start' -d 'Start a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'stop' -d 'Stop a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'submodule' -d 'Add a package as a git submodule'
complete -f -c npm -n '__fish_npm_needs_command' -a 't tst test' -d 'Test a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'unpublish' -d 'Remove a package from the registry'
complete -f -c npm -n '__fish_npm_needs_command' -a 'unstar' -d 'Remove star from a package'
complete -f -c npm -n '__fish_npm_needs_command' -a 'version' -d 'Bump a package version'
complete -f -c npm -n '__fish_npm_needs_command' -a 'whoami' -d 'Display npm username'