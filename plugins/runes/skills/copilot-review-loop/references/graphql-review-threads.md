# GraphQL fallback for Copilot review threads

Use this when Copilot's latest review body says it generated comments, but `GET /repos/{owner}/{repo}/pulls/{pr}/comments` returns no comments for `pull_request_review_id`.

## Why

GitHub's REST pull-request comments endpoint can miss unresolved Copilot review threads that are visible through GraphQL `reviewThreads`. Do not conclude "no comments" from REST alone unless the latest Copilot review body also says `generated no new comments`.

## Query unresolved Copilot threads

```bash
gh api graphql \
  -f owner="$OWNER" \
  -f repo="$REPO" \
  -F pr="$PR" \
  -f query='query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes {
            id
            isResolved
            path
            line
            comments(first:20) {
              nodes {
                id
                databaseId
                author { login }
                body
                url
                outdated
              }
            }
          }
        }
      }
    }
  }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.isResolved == false)
        | select([.comments.nodes[].author.login | ascii_downcase | contains("copilot")] | any)
        | {threadId:.id, path, line, comments:.comments.nodes}'
```

## Resolve a thread after replying/fixing

```bash
gh api graphql \
  -f threadId="$THREAD_ID" \
  -f query='mutation($threadId:ID!) {
    resolveReviewThread(input:{threadId:$threadId}) { thread { id isResolved } }
  }'
```

## Loop rule

If REST returns empty but GraphQL shows unresolved Copilot threads, handle those threads with the normal verify → fix or push-back → reply → resolve cycle, then re-request Copilot review. Terminate only when the newest Copilot review body contains `generated no new comments`.
