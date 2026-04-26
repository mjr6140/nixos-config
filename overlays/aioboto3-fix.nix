final: prev: {
  pythonPackagesExtensions =
    (prev.pythonPackagesExtensions or [ ])
    ++ [
      (python-final: python-prev: {
        aioboto3 = python-prev.aioboto3.overridePythonAttrs (old: {
          disabledTests =
            (old.disabledTests or [ ])
            ++ [
              # TODO: Remove this workaround once nixpkgs/aioboto3 no longer
              # fails these tests with the current HTTP stack.
              # Upstream test breakage with the current HTTP stack:
              # botocore.exceptions.HTTPClientError: Duplicate 'Server' header found.
              "test_dynamo_resource_query"
              "test_dynamo_resource_put"
              "test_dynamo_resource_batch_write_flush_on_exit_context"
              "test_dynamo_resource_batch_write_flush_amount"
              "test_flush_doesnt_reset_item_buffer"
              "test_dynamo_resource_property"
              "test_dynamo_resource_waiter"
            ];
        });
      })
    ];
}
