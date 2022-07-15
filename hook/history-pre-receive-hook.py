#!/usr/bin/python3

########################################
# Git Hook used with git-remote-gcrypt #
########################################

import sys
import fileinput
import os
import subprocess
import re
from datetime import datetime

manifestfile = "91bd0c092128cf2e60e1a608c31e92caf1f9c1595f83f2890ef17c0e4881aa0a"


class CommitInformation:
    history_keys: list[str]
    new_message_first_line: str
    new_message: list[str]
    new_commit_hash: str
    new_branch: bool


def read_commit_msg():
    '''
    Reads the input (stdin) [previous commit id, new commit id, branch] of the current push
    Returns the mentioned keys in the commit message, the first line of the commit message, the rest of the commit message
    the hash of the newest commit and wether this is a new branch or not
    '''
    result = CommitInformation()#used for returning values

    stdin_line = sys.stdin.readline()
    
    print("pre-receive: Trying to push ref: ",stdin_line)
    [prevhash, newhash, branch] = stdin_line.split() #format: [previous commit id, new commit id, branch]
    result.new_commit_hash = newhash

    #check if it is a push to a new branch or deleted
    new_branch = bool(re.match(r'[0]{40}', prevhash)) #if previous commit id is all zeros
    branch_deleted = bool(re.match(r'[0]{40}', newhash)) #if new commit id is all zeros
    if branch_deleted:
        sys.exit(0)
    result.new_branch = new_branch
    
    #The commit message of the new push (NOT TRUSTED)
    proc = subprocess.Popen(['git', 'rev-list','--format=%an %ai %b','--first-parent', newhash], stdout=subprocess.PIPE)
    new_message = proc.stdout.readlines()
    new_message = [line.decode().strip() for line in new_message]
    new_message = [line for line in new_message if line]#remove empty lines
    if len(new_message)<=2:
        print("There is no history in the commit message")
        sys.exit(1)
    new_message_first_line = new_message[2] #this should be equal to the first line of the last commit message
    result.new_message_first_line = new_message_first_line
    

    #Keys that are mentioned in the commit message for the current manifestfile
    pattern = r"<(\w{16})>"#Assumption: Git username contains no " ", "<", ">" symbols
    histkeys = []
    for match in re.finditer(pattern, new_message[1]):
        histkeys.append(match.group(1))
    result.history_keys = histkeys

    #extract the previous commit message of the new commit message
    if len(new_message) > 2:
        new_message = new_message[2:]
        firstkey = re.search(r'(<\w{16}>)', new_message[0]).start()
        if firstkey:  # cut to only have the keys in the first line of the whole commit history
            new_message[0] = new_message[0][firstkey:]
    else:
        new_message=""
    result.new_message = new_message
    
    return result


def check_history(commit_info):
    '''
    new_message_first_line: the first line of the commit message
    lines: the remaining lines of the new commit message
    Checks that the commit message matches the information in git log
    '''
    new_message_first_line = commit_info.new_message_first_line
    new_message = commit_info.new_message
    new_branch = commit_info.new_branch
    
    #extract information from git log
    proc = subprocess.Popen(['git', '--no-pager', 'log', '--format="%h"'], stdout=subprocess.PIPE)
    gitlog_hash = proc.stdout.readline().decode()
    gitlog_hash = gitlog_hash.replace("\n", "").replace('"', "")

    proc = subprocess.Popen(['git', '--no-pager', 'log', '--format="%an"'], stdout=subprocess.PIPE)
    gitlog_author = proc.stdout.readline().decode()
    gitlog_author= gitlog_author.replace("\n", "").replace('"', "")

    proc = subprocess.Popen(['git', '--no-pager', 'log', '--format="%ai"'], stdout=subprocess.PIPE)
    gitlog_time = proc.stdout.readline().decode()
    gitlog_time = gitlog_time.replace("\n", "").replace('"', "")

    proc = subprocess.Popen(['git', '--no-pager', 'log', '--format="%b"'], stdout=subprocess.PIPE)
    gitlog_oldmsg = [line.decode() for line in proc.stdout.readlines()]
    gitlog_oldmsg = [line.replace('"', "").replace("\\n", "").strip() for line in gitlog_oldmsg]
    gitlog_oldmsg = [line for line in gitlog_oldmsg if line]#remove empty lines

    #first line and first thing of the log's commit message should only be keys
    keys_end = re.match(r"(<\w+> ?)+",gitlog_oldmsg[0]).end()
    gitlog_keys = gitlog_oldmsg[0][:keys_end].strip()
    
    #when new branch, gitlog is of length zero
    if len(gitlog_hash)==0 and new_branch:
        return

    #compare the newest line in the history with the information from git log (current newest information in git log)
    gitlog_newest = " ".join([gitlog_time, gitlog_author, gitlog_hash, gitlog_keys])
    if not new_message_first_line == gitlog_newest:
        print("The first line in the Commit Message does not match git log")
        print("commit:", new_message_first_line)
        print("git log:", gitlog_newest)
        sys.exit(1)


    #Compare the remaining lines of the history to git log
    if len(gitlog_oldmsg) != len(new_message):
        print("number of lines in git log and the commit message do not match")
        sys.exit(1)
    for i in range(len(gitlog_oldmsg)):
        if not gitlog_oldmsg[i]==new_message[i]:
            print("Commit Message (History) does not match gitlog:")
            print("correct:", gitlog_oldmsg[i])
            print("yours:", new_message[i])
            sys.exit(1)



def check_manifest(commit_info):
    '''
    histkeys: list of strings (the key ids that are mentioned in the commit message)
    newhash: the commit hash (ID) of the pushed commit
    Checks that the keys (IDs) that are able to decrypt the manifest file and the keys mentioned in the commit message are identical
    '''
    histkeys = commit_info.history_keys
    newhash = commit_info.new_commit_hash

    #find out for which keys the manifestfile was encrypted
    try: #get the pushed manifestfile and run gpg --list-packets on it
        manifest_content = subprocess.check_output(['git', 'show', newhash+":"+manifestfile])
        listpackets = subprocess.run(['gpg', '--list-packets'], input = manifest_content, capture_output=True)
    except subprocess.CalledProcessError as e:
        print("GPG Exception: ", e.output.decode())
        print("returncode:", e.returncode)
        sys.exit(1)
    if listpackets.returncode!=2:#gpg should always have exit code 2 because it fails to decrypt
        print("gpg failed with return code:")
        print("returncode:", listpackets.returncode)
        sys.exit(1)
    gpg_output = listpackets.stdout.decode()

    #find all occurances of " keyid KEY" in the previous gpg output to find all key IDs
    pattern = r" keyid (\w{16})"
    filekeys = []
    for match in re.finditer(pattern, gpg_output):
        filekeys.append(match.group(1))

    #check that all keys that the file is encrypted for are in the commit message
    for fkey in filekeys:
        if not fkey in histkeys:
            print("There has a key (" + fkey + ") access to the manifest file which is not mentioned in the Commit History, or no keys have been added!")
            print(fkey, "not in", histkeys)
            sys.exit(1)


    #check that all keys that are in the commit message are able to decrpyt the manifest
    for hkey in histkeys:
        if not hkey in filekeys:
            print("There is a key (" + hkey + ") in the Commit Message that does not have access to the manifest file!")
            print(hkey, "not in", filekeys)
            sys.exit(1) 



commit_info = read_commit_msg()

check_history(commit_info)

check_manifest(commit_info)



print(">>> PUSH ACCEPTED")
sys.exit(0)
