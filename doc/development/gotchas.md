# Gotchas

The purpose of this guide is to document potential "gotchas" that contributors
might encounter or should avoid during development of GitLab CE and EE.

## Do not assert against the absolute value of a sequence-generated attribute

Consider the following factory:

```ruby
FactoryBot.define do
  factory :label do
    sequence(:title) { |n| "label#{n}" }
  end
end
```

Consider the following API spec:

```ruby
require 'spec_helper'

describe API::Labels do
  it 'creates a first label' do
    create(:label)

    get api("/projects/#{project.id}/labels", user)

    expect(response).to have_http_status(200)
    expect(json_response.first['name']).to eq('label1')
  end

  it 'creates a second label' do
    create(:label)

    get api("/projects/#{project.id}/labels", user)

    expect(response).to have_http_status(200)
    expect(json_response.first['name']).to eq('label1')
  end
end
```

When run, this spec doesn't do what we might expect:

```sh
1) API::API reproduce sequence issue creates a second label
   Failure/Error: expect(json_response.first['name']).to eq('label1')

     expected: "label1"
          got: "label2"

     (compared using ==)
```

This is because FactoryBot sequences are not reset for each example.

Please remember that sequence-generated values exist only to avoid having to
explicitly set attributes that have a uniqueness constraint when using a factory.

### Solution

If you assert against a sequence-generated attribute's value, you should set it
explicitly. Also, the value you set shouldn't match the sequence pattern.

For instance, using our `:label` factory, writing `create(:label, title: 'foo')`
is ok, but `create(:label, title: 'label1')` is not.

Following is the fixed API spec:

```ruby
require 'spec_helper'

describe API::Labels do
  it 'creates a first label' do
    create(:label, title: 'foo')

    get api("/projects/#{project.id}/labels", user)

    expect(response).to have_http_status(200)
    expect(json_response.first['name']).to eq('foo')
  end

  it 'creates a second label' do
    create(:label, title: 'bar')

    get api("/projects/#{project.id}/labels", user)

    expect(response).to have_http_status(200)
    expect(json_response.first['name']).to eq('bar')
  end
end
```

## Avoid using `expect_any_instance_of` or `allow_any_instance_of` in RSpec

### Why

- Because it is not isolated therefore it might be broken at times.
- Because it doesn't work whenever the method we want to stub was defined
  in a prepended module, which is very likely the case in EE. We could see
  error like this:

  ```
  1.1) Failure/Error: expect_any_instance_of(ApplicationSetting).to receive_messages(messages)
       Using `any_instance` to stub a method (elasticsearch_indexing) that has been defined on a prepended module (EE::ApplicationSetting) is not supported.
  ```

### Alternative: `expect_next_instance_of`

Instead of writing:

```ruby
# Don't do this:
expect_any_instance_of(Project).to receive(:add_import_job)
```

We could write:

```ruby
# Do this:
expect_next_instance_of(Project) do |project|
  expect(project).to receive(:add_import_job)
end
```

If we also want to expect the instance was initialized with some particular
arguments, we could also pass it to `expect_next_instance_of` like:

```ruby
# Do this:
expect_next_instance_of(MergeRequests::RefreshService, project, user) do |refresh_service|
  expect(refresh_service).to receive(:execute).with(oldrev, newrev, ref)
end
```

This would expect the following:

```ruby
# Above expects:
refresh_service = MergeRequests::RefreshService.new(project, user)
refresh_service.execute(oldrev, newrev, ref)
```

## Do not `rescue Exception`

See ["Why is it bad style to `rescue Exception => e` in Ruby?"](https://stackoverflow.com/questions/10048173/why-is-it-bad-style-to-rescue-exception-e-in-ruby).

_**Note:** This rule is [enforced automatically by
Rubocop](https://gitlab.com/gitlab-org/gitlab/blob/8-4-stable/.rubocop.yml#L911-914)._

## Do not use inline JavaScript in views

Using the inline `:javascript` Haml filters comes with a
performance overhead. Using inline JavaScript is not a good way to structure your code and should be avoided.

_**Note:** We've [removed these two filters](https://gitlab.com/gitlab-org/gitlab/blob/master/config/initializers/hamlit.rb)
in an initializer._

### Further reading

- Stack Overflow: [Why you should not write inline JavaScript](https://softwareengineering.stackexchange.com/questions/86589/why-should-i-avoid-inline-scripting)
