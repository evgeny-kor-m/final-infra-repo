#!/bin/bash
set -e
STATUS=0
trap 'echo "ERROR: Script failed at line $LINENO with exit code $?"' ERR
 
function usage {
        echo;echo
        cat << EOF
Usage:
$(basename $0) --message <"COMMIT-MSG-VAL"> --repo <"REPO"> [--base <"BASE-BRANCH">] [--head <"HEAD-BRANCH">]
 
Examples -
$(basename $0) --message "COMMIT-MSG-VAL" --repo "owner/repo-name"
$(basename $0) --message "COMMIT-MSG-VAL" --repo "owner/repo-name" --base main --head DEV
EOF
}
 
function validateInput {
    STATUS=0
    BASE_BRANCH="main"
    HEAD_BRANCH="DEV"
 
    while [[ $# -gt 0 ]]; do
        case ${1} in
            "--message") COMMIT_MSG="${2}"; shift; shift ;;
            "--repo")    GIT_REPO="${2}";   shift; shift ;;
            "--base")    BASE_BRANCH="${2}"; shift; shift ;;
            "--head")    HEAD_BRANCH="${2}"; shift; shift ;;
            *) echo "ERROR: ${1} - unrecognized option"; STATUS=1; shift ;;
        esac
    done
 
    if [[ -z ${COMMIT_MSG} || -z ${GIT_REPO} ]]; then
        STATUS=1
    fi
 
    if [[ ${STATUS} -eq 1 ]]; then
        usage && exit 1
    fi
}
 
function get_ahead_by_stats {
        echo "Checking num commits ..."
        COMMITS_AHEAD=$(gh api "repos/${GIT_REPO}/compare/${BASE_BRANCH}...${HEAD_BRANCH}" --jq '.ahead_by')
 
        if [ "$COMMITS_AHEAD" -eq 0 ]; then
                echo "No new commits, skipping."
                exit 0
        fi
        echo "Num of new commits: ${COMMITS_AHEAD}"
}
 
function search_pr_request {
        echo "Searching for open PR..."
        PR_NUMBER=$(gh pr list --repo "${GIT_REPO}" --head "${HEAD_BRANCH}" --base "${BASE_BRANCH}" --state open --json number --jq '.[0].number' || true)
 
        if [ -z "$PR_NUMBER" ]; then
                echo "PR not found..."
        else
                echo "Found PR #${PR_NUMBER}..."
        fi
}
 
function create_pr {
        if [ -z "$PR_NUMBER" ]; then
                echo "Creating new PR..."
                PR_NUMBER=$(gh pr create --repo "${GIT_REPO}" --title "${COMMIT_MSG}" --head "${HEAD_BRANCH}" --base "${BASE_BRANCH}" --body "" | grep -o '[0-9]*$')
                echo "PR #${PR_NUMBER} created!"
        else
                echo "PR already exists #${PR_NUMBER}, skipping..."
        fi
}
 
function merge_pr_request {
        if [[ ! -z "$PR_NUMBER" ]]; then
                echo "Merging PR #${PR_NUMBER}..."
                gh pr merge "${PR_NUMBER}" --repo "${GIT_REPO}" --merge
                echo "PR #${PR_NUMBER} merged to ${BASE_BRANCH}!"
        else
                echo "Error: No PR number found to merge."
                exit 1
        fi
}
 
validateInput "$@"
 
# echo $GH_TOKEN
get_ahead_by_stats
search_pr_request
create_pr
sleep 5
search_pr_request
merge_pr_request