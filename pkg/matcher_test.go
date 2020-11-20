package pkg

import (
	"context"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

var _ = Describe("test byName matcher", func() {
	It("should pass on the matched configmap", func() {
		key := types.NamespacedName{Name: "a", Namespace: "default"}
		obj := &corev1.ConfigMap{
			ObjectMeta: metav1.ObjectMeta{
				Name:      key.Name,
				Namespace: key.Namespace,
			},
		}

		Expect(k8sClient.Create(context.TODO(), obj)).Should(Succeed())

		defer func() {
			Expect(k8sClient.Delete(context.TODO(), obj))
		}()

		ep := Expectation{
			APIVersion: "v1",
			Kind:       "ConfigMap",
			Name:       key.Name,
			Namepsace:  key.Namespace,
			Matcher:    "byname",
		}

		Expect(checkExpectation(k8sClient, ep)).Should(Succeed())
	})

	It("should not pass due to incorrect at the expectation name", func() {
		key := types.NamespacedName{Name: "a", Namespace: "default"}
		obj := &corev1.ConfigMap{
			ObjectMeta: metav1.ObjectMeta{
				Name:      key.Name,
				Namespace: key.Namespace,
			},
		}

		Expect(k8sClient.Create(context.TODO(), obj)).Should(Succeed())

		defer func() {
			Expect(k8sClient.Delete(context.TODO(), obj))
		}()

		ep := Expectation{
			APIVersion: "v1",
			Kind:       "ConfigMap",
			Name:       key.Name + "a",
			Namepsace:  key.Namespace,
			Matcher:    "byname",
		}

		Expect(checkExpectation(k8sClient, ep)).ShouldNot(Succeed())
	})
})

var _ = Describe("test ByAnnotation matcher", func() {
	It("should pass on the matched configMap by annotation", func() {
		key := types.NamespacedName{Name: "a", Namespace: "default"}
		insAnnotation := map[string]string{
			"configmap-test": "byAnnotation",
		}
		obj := &corev1.ConfigMap{
			ObjectMeta: metav1.ObjectMeta{
				Name:        key.Name,
				Namespace:   key.Namespace,
				Annotations: insAnnotation,
			},
		}

		Expect(k8sClient.Create(context.TODO(), obj)).Should(Succeed())

		defer func() {
			Expect(k8sClient.Delete(context.TODO(), obj))
		}()

		ep := Expectation{
			APIVersion: "v1",
			Kind:       "ConfigMap",
			Name:       key.Name + "a",
			Namepsace:  key.Namespace,
			Matcher:    "byannotation",
			Args:       map[string]string{"configmap-test": "byAnnotation"},
		}

		Expect(checkExpectation(k8sClient, ep)).Should(Succeed())
	})

	It("should pass on the matched configMap by annotation", func() {
		key := types.NamespacedName{Name: "a", Namespace: "default"}
		insAnnotation := map[string]string{
			"configmap-test": "byAnnotation",
		}
		obj := &corev1.ConfigMap{
			ObjectMeta: metav1.ObjectMeta{
				Name:        key.Name,
				Namespace:   key.Namespace,
				Annotations: insAnnotation,
			},
		}

		Expect(k8sClient.Create(context.TODO(), obj)).Should(Succeed())

		defer func() {
			Expect(k8sClient.Delete(context.TODO(), obj))
		}()

		ep := Expectation{
			APIVersion: "v1",
			Kind:       "ConfigMap",
			Name:       key.Name + "a",
			Namepsace:  key.Namespace,
			Matcher:    "byannotation",
			Args:       map[string]string{"a-configmap-test": "byAnnotation"},
		}

		Expect(checkExpectation(k8sClient, ep)).ShouldNot(Succeed())
	})
})
