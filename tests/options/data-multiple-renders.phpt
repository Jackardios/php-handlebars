--TEST--
Handlebars\Options::$data - Multiple renders with same VM
--SKIPIF--
<?php if( !extension_loaded('handlebars') ) die('skip '); ?>
--FILE--
<?php
use Handlebars\VM;
use Handlebars\DefaultRegistry;
use Handlebars\Options;

$registry = new DefaultRegistry();
$registry['test'] = function ($val, Options $options) {
    // Access the value from the context passed as parameter
    if (is_array($val) && isset($val['value'])) {
        return "root: " . $val['value'];
    }
    // data property should be set for this to demonstrate it persists across renders
    $data_set = $options->data !== null ? 'yes' : 'no';
    return "no root (data: $data_set)";
};

$vm = new VM();
$vm->setHelpers($registry);

$template = '{{test this}}';
$context = ['value' => 'test123'];

// First render
$result1 = $vm->render($template, $context);
var_dump($result1);

// Second render - data should still be available
$result2 = $vm->render($template, $context);
var_dump($result2);

// Third render - data should still be available
$result3 = $vm->render($template, $context);
var_dump($result3);

// All results should be identical
var_dump($result1 === $result2 && $result2 === $result3);
--EXPECT--
string(13) "root: test123"
string(13) "root: test123"
string(13) "root: test123"
bool(true)
