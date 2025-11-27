--TEST--
Handlebars\Options::$scope - Multiple renders with same VM
--SKIPIF--
<?php if( !extension_loaded('handlebars') ) die('skip '); ?>
--FILE--
<?php
use Handlebars\VM;
use Handlebars\DefaultRegistry;
use Handlebars\Options;

$registry = new DefaultRegistry();
$registry['test'] = function ($val, Options $options) {
    $name = $options->scope['name'] ?? '';
    return "Hello, $name!";
};

$vm = new VM();
$vm->setHelpers($registry);

$template = '{{test this}}';
$context = ['name' => 'World'];

// First render
$result1 = $vm->render($template, $context);
var_dump($result1);

// Second render - scope should still be available
$result2 = $vm->render($template, $context);
var_dump($result2);

// Third render - scope should still be available
$result3 = $vm->render($template, $context);
var_dump($result3);

// All results should be identical
var_dump($result1 === $result2 && $result2 === $result3);
--EXPECT--
string(13) "Hello, World!"
string(13) "Hello, World!"
string(13) "Hello, World!"
bool(true)
